require 'result'

module Jade
  module Parser
    extend self

    FunctionCallPostfix = Data.define(:lparen, :args, :rparen) do
      def apply(node)
        AST.function_call.call(node, lparen, args, rparen)
      end
    end

    MemberAccessPostfix = Data.define(:dot, :identifier) do
      def apply(node)
        AST.member_access.call(node, dot, identifier)
      end
    end

    def parse(tokens, parser = program)
      parser
        .call(State.new(tokens.reject { it.type == :comment }))
        .map(&:first)
        .map_error(&:first)
    end

    def module_
      (
        type(:module).skip >>
        (
          module_name >>
          exposing >>
          program_body
        ).map_error(&:commit)
      ).map(&AST.module_)
    end

    def program
      module_ | program_body
    end

    def program_body
      sequence(declaration | statement).map(&AST.body)
    end

    def statement
      variable_binding | expression
    end

    def declaration
      function_declaration | type_declaration | import_declaration
    end

    def expression
      case_of | if_then_else | lambda | infix_expression
    end

    def grouping
      (type(:lparen) >> lazy { expression } >> type(:rparen)).map(&AST.grouping)
    end

    def infix_expression
      (primary >> many(operator >> primary))
        .map do |(head, *tail)|
          tail.reduce(head) do |left, (op, right)|
            AST.infix_application.call(left, op, right)
          end
        end
    end

    def lambda
      (
        type(:lparen) >>
          (sequence(lambda_param, separated_by: type(:comma).skip).map { [it] } | none.map { [[]] }) >>
          type(:rparen).skip >>
          type(:arrow).skip >>
          type(:lbrace).skip >>
          body >>
          type(:rbrace)
      ).map(&AST.lambda)
    end

    def lambda_param
      identifier.map(&AST.lambda_param)
    end

    def if_then_else
      (
        type(:if) >>
          lazy { expression } >>
          type(:then).skip >>
          body >>
          type(:else).skip >>
          body >>
          type(:end)
      ).map(&AST.if_then_else)
    end

    def case_of
      (
        type(:case) >>
          lazy { expression } >>
          sequence(case_of_branch).map { [it] } >>
          type(:end)
      ).map(&AST.case_of)
    end

    def case_of_branch
      (type(:of) >> pattern >> type(:then).skip >> body).map(&AST.case_of_branch)
    end

    def pattern
      wildcard_pattern | literal_pattern | binding_pattern | constructor_pattern
    end

    def wildcard_pattern
      type(:wildcard).map(&AST.wildcard_pattern)
    end

    def binding_pattern
      identifier.map(&AST.binding_pattern)
    end

    def literal_pattern
      literal.map(&AST.literal_pattern)
    end

    def constructor_pattern
      (constructor_reference >>
        ((type(:lparen).skip >>
        (sequence(lazy { pattern }, separated_by: type(:comma).skip).map { [it] } |
          none.map { [[]] }) >>
        type(:rparen)) | none.map { [[]] })
      ).map(&AST.constructor_pattern)
    end

    def body
      sequence(lazy { expression }).map(&AST.body)
    end

    def operator
      type(:plus) | type(:minus) | type(:star) | type(:slash) |
        type(:pipe_forward) | type(:pipe_backward)
    end

    def primary
      (atom >> many(postfix))
        .map do |(node, *postfixes)|
          postfixes.reduce(node) do |acc, postfix_type|
            postfix_type.apply(acc)
          end
        end
    end

    def atom
      variable_reference | literal | constructor_reference | grouping | record_literal |
       record_update_sugar | record_access_sugar | record_update
    end

    def postfix
      function_call | member_access
    end

    def module_name
      sequence(constant, separated_by: type(:dot).skip).map { [it] }
    end

    def function_call
      (
        type(:lparen) >> 
          (sequence(lazy { expression }, separated_by: type(:comma).skip).map { [it] } |
            none.map { [[]] }) >>
          type(:rparen)
      ).map { FunctionCallPostfix[*it] }
    end

    def member_access
      (type(:dot) >> (variable_reference | constructor_reference))
        .map { MemberAccessPostfix[*it] }
    end

    def import_declaration
      (
        type(:import) >>
        module_name >>
        ((type(:as).skip >> constant).map(&AST.expose_as) | none.map { [nil] }) >>
        (exposing | none.map { [[]] })
      ).map(&AST.import_declaration)
    end

    def exposing
      (type(:exposing).skip >>
          type(:lparen).skip >>
          (expose_list | expose_all) >>
          type(:rparen).skip
      ) | expose_none
    end

    def expose_none
      none.map(&AST.expose_none)
    end

    def expose_all
      type(:dotdot).map(&AST.expose_all)
    end

    def expose_list
      (sequence(expose_item, separated_by: type(:comma).skip))
        .map { [it] }.map(&AST.expose_list)
    end

    def expose_item
      expose_value | expose_type_expand | expose_type
    end

    def expose_value
      identifier.map(&AST.expose_value)
    end

    def expose_type_expand
      (constant >> type(:lparen) >> type(:dotdot) >> type(:rparen))
        .map(&AST.expose_type_expand)
    end

    def expose_type
      constant.map(&AST.expose_type)
    end

    def function_declaration
      (
        type(:def) >>
          (
            identifier >>
            type(:lparen).skip >>
            (sequence(param, separated_by: type(:comma).skip).map { [it] } | none.map { [[]] }) >>
            type(:rparen).skip >>
            type(:arrow).skip >>
            type_expression >>
            sequence(statement).map(&AST.body) >>
            type(:end)
          ).map_error(&:commit)
      ).map(&AST.function_declaration)
    end

    def type_declaration
      (
        type(:type) >>
          constant >>
          (type_params | none.map { [[]] }) >>
          type(:assign).skip >>
          sequence(variant_declaration, separated_by: type(:pipe).skip).map { [it] }
      ).map(&AST.type_declaration)
    end

    def variant_declaration
      (
        constant >>
          (type_expressions | none.map { [[]] })
      ).map(&AST.variant_declaration)
    end

    def type_params
      type(:lparen).skip >>
        sequence(type_param, separated_by: type(:comma).skip).map { [it] } >>
        type(:rparen).skip
    end

    def type_expressions
      type(:lparen).skip >>
        sequence(type_expression, separated_by: type(:comma).skip).map { [it] } >>
        type(:rparen).skip
    end

    def type_param
      identifier.map(&AST.type_param)
    end

    def type_atom
      type_var | type_application | type_name | grouped(lazy { type_function })
    end

    def type_expression
      type_function | type_atom | type_record
    end

    def type_record
      (type(:lbrace) >> type_record_row >> type_record_fields >> type(:rbrace)).map(&AST.type_record)
    end

    def type_record_row
      (type_param >> type(:pipe).skip) | none.map { nil }
    end

    def type_record_fields
      sequence(
        (identifier >>
          type(:colon).skip >>
          lazy { type_expression }
        ).map { [it] },
        separated_by: type(:comma).skip,
      ).map { [it] }
    end

    def type_name
       qualified_type_name | constant.map(&AST.type_name)
    end

    def qualified_type_name
      (constant >> type(:dot).skip >> 
        sequence(constant, separated_by: type(:dot).skip)
      ).map(&AST.qualified_type_name)
    end

    def type_var
      identifier.map(&AST.type_var)
    end

    def type_function
      (sequence(type_atom, separated_by: type(:comma).skip).map { [it] } >>
        type(:arrow).skip >>
        type_atom
      ).map(&AST.type_function)
    end

    def grouped(parser)
      type(:lparen).skip >> parser >> type(:rparen).skip
    end

    def type_application
      (type_name >> type(:lparen) >> sequence(lazy { type_expression }, separated_by: type(:comma).skip) >> type(:rparen))
        .map(&AST.type_application)
    end

    def literal
      string | int | bool | list
    end

    def list
      (type(:lbrack) >>
        (sequence(lazy { expression }, separated_by: type(:comma).skip)).map { [it] } >>
        type(:rbrack)
      ).map(&AST.list)
    end

    # Should refactor to just an Identifier node
    def variable_reference
      identifier.map(&AST.variable_reference)
    end

    # Should refactor to just an Constant node
    def constructor_reference
      constant.map(&AST.constructor_reference)
    end

    def param
      (
        identifier >> type(:colon).skip >> type_expression
      ).map(&AST.function_declaration_param)
    end

    def variable_binding
      (
        identifier >>
          type(:assign) >>
          (expression).map_error(&:commit)
      ).map(&AST.variable_binding)
    end

    def many(parser)
      P.new do |state|
        oks = []
        current = state

        loop do
          break if current.eof?

          case parser.call(current)
          in Ok([value, next_state])
            oks << value
            current = next_state
          in Err([err, err_state])
            current = err_state
            break
          end
        end

        Ok[[oks, current]]
      end
    end

    # Records
    def record_literal
      (type(:lbrace) >> record_fields >> type(:rbrace)).map(&AST.record_literal)
    end

    def record_fields
      sequence(record_field, separated_by: type(:comma).skip)
        .map { [it] }
    end

    def record_field
      (identifier >> type(:colon).skip >> lazy { expression }).map(&AST.record_field)
    end

    def record_access_sugar
      (type(:dot) >> type(:identifier)).map(&AST.record_access_sugar)
    end

    def record_update
      (type(:lbrace) >> variable_reference >> type(:pipe) >> record_fields >> type(:rbrace)).map(&AST.record_update)
    end

    def record_update_sugar
      (type(:dot) >> type(:identifier) >> type(:assign)).map(&AST.record_update_sugar)
    end

    private

    def sequence(parser, separated_by: none.skip)
      (parser.map { [it] } >> many(separated_by >> parser))
        .map { it.flatten(1) }
    end

    def none
      P.new { |state| Ok[[nil, state]] }
    end

    def skip(parser)
      parser.map { |_| :skip }
    end

    def int
      type(:int).map(&AST.literal)
    end

    def bool
      type(:bool).map(&AST.literal)
    end

    def string
      (
        type(:quote) >>
          (type(:string_chunk) >> type(:quote))
            .map_error(&:commit)
      )
        .map(&AST.string_literal)
    end

    def identifier
      type(:identifier)
    end

    def constant
      type(:constant)
    end

    def type(type)
      P.new do |state|
        if state.eof?
          Err[[
            EOFError.new(
              expected: type,
              position: state.position,
            ),
            state,
          ]]

        elsif state.current.type == type
          Ok[([state.current, state.advance])]

        else
          Err[[
            UnexpectedTokenError.new(
              actual: state.current,
              expected: type,
              position: state.position,
            ),
            state,
          ]]
        end
      end
    end

    def lazy(&block)
      P.new do |input|
        block.call.call(input)
      end
    end

    State = Data.define(:tokens, :position, :context_stack) do
      def initialize(tokens:, position: 0, context_stack: [])
        super
      end

      def current
        tokens[position]
      end

      def advance(n = 1)
        with(tokens:, position: position + n)
      end

      def eof?
        position >= tokens.length
      end
    end

    class P
      def initialize(&block)
        @fn = block
      end

      def call(tokens)
        @fn.call(tokens)
      end

      def map(&block)
        P.new do |state|
          call(state)
            .map { |(value, ok_state)| [block.call(value), ok_state] }
        end
      end

      def map_error(&block)
        P
          .new do |state|
            call(state)
              .map_error { |(err, err_state)| [block.call(err), err_state] }
          end
      end

      def |(other)
        P.new do |state|
          call(state)
            .on_err do |(error, state2)|
              if error.committed?
                Err[[error, state2]]
              else
                other.call(state)
              end
            end
        end
      end

      def >>(other)
        P.new do |state|
          call(state).and_then do |(value1, state1)|
            other.call(state1)
              .map do |(value2, state2)|
                [[value1, value2].reject { it == :skip }.flatten(1), state2]
              end
              .map_error do |(err, err_state)|
                [err, state]
              end
          end
        end
      end

      def skip
        self.map { |_| :skip }
      end

      def many
        Parser.many(self)
      end
    end

    class Error
      def initialize(position:, actual:, expected:, committed: false)
        @position = position
        @actual = actual
        @expected = expected
        @committed = committed
      end

      def committed?
        @committed
      end

      def commit
        @committed = true
        self
      end

      protected

      attr_reader :actual, :expected
    end

    class EOFError < Error
      def initialize(position:, actual: nil, expected:, committed: false)
        super
      end

      def message
        "Unexpected end of input, expected #{expected}"
      end
    end

    class UnexpectedTokenError < Error
      def initialize(position:, actual:, expected:, committed: false)
        super
      end

      def message
        "Unexpected end token #{actual}, #{expected}"
      end
    end
  end
end
