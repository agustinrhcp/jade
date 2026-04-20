require 'result'
require 'jade/parsing/combinators'
require 'jade/parsing/type'
require 'jade/parsing/token'

module Jade
  module Parsing
    extend self
    include Combinators
    include Token
    include Type

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
      bind | variable_binding | expression
    end

    def declaration
      function_declaration | type_declaration | import_declaration | interop_import_declaration |
        struct_declaration | implementation
    end

    def expression
      case_of | if_then_else | lambda | infix_expression
    end

    def tuple
      (
        type(:lparen) >>
          lazy { expression } >>
          type(:comma).skip >>
          sequence(lazy { expression }, separated_by: type(:comma).skip).map { [it] } >>
          type(:rparen)
      ).map(&AST.tuple)
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
      wildcard_pattern | literal_pattern | binding_pattern | constructor_pattern | tuple_pattern | record_pattern
    end

    def tuple_pattern
      (
        type(:lparen) >>
          lazy { pattern } >>
          type(:comma).skip >>
          sequence(lazy { pattern }, separated_by: type(:comma).skip).map { [it] } >>
          type(:rparen)
      ).map(&AST.tuple_pattern)
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

    def record_pattern
      (
        type(:lbrace) >>
        sequence(record_field_pattern, separated_by: type(:comma).skip).map { [it] } >>
        type(:rbrace)
      ).map(&AST.record_pattern)
    end

    def record_field_pattern
      (
        (identifier >> type(:colon) >> lazy { pattern }) | 
          (identifier >> type(:colon))
            .map { |identifier, colon| [identifier, colon, AST.binding_pattern.call(identifier)] }
      ).map(&AST.record_field_pattern)
    end

    def body
      sequence(lazy { expression }).map(&AST.body)
    end

    def operator
      type(:plus) | type(:minus) | type(:star) | type(:slash) |
        type(:pipe_forward) | type(:pipe_backward) | type(:eq) | type(:not_eq) |
        type(:lt) | type(:gt) | type(:lte) | type(:gte) | type(:andand)
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
      variable_reference | literal | constructor_reference | tuple | grouping | record_literal |
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

    def record_declaration
      (
        type(:data) >>
          constant >>
          (type_params | none.map { [[]] }) >>
          type(:assign).skip >>
          type_record
      ).map(&AST.record_declaration)
    end

    def variant_declaration
      (
        constant >>
          (type_expressions | none.map { [[]] })
      ).map(&AST.variant_declaration)
    end

    def literal
      string | int | bool | float | list
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

    def bind
      (
        identifier >>
          type(:bind) >>
          (expression).map_error(&:commit)
      ).map(&AST.bind)
    end

    def variable_binding
      (
        identifier >>
          type(:assign) >>
          (expression).map_error(&:commit)
      ).map(&AST.variable_binding)
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

    def interop_import_declaration
      (type(:uses) >> interop_module_name >> type(:with) >> interop_functions)
        .map(&AST.interop_import_declaration)
    end

    def interop_namespace_sep
      type(:coloncolon)
    end

    def interop_module_name
      at_least_one(constant, separated_by: interop_namespace_sep.skip)
        .map(&AST.interop_module)
    end

    def interop_functions
      at_least_one(interop_function, separated_by: type(:comma).skip)
        .map { [it] }
    end

    def interop_function
      (identifier >> type(:colon).skip >> type_expression )
        .map(&AST.interop_function)
    end

    def implementation
      (
        type(:implements) >>
          type(:constant) >>
          type(:lparen).skip >>
          type_application >>
          type(:rparen).skip >>
          (type(:extends).skip >> at_least_one(constant, separated_by: type(:comma).skip) | none.map { [] })
            .map { [it] } >>
          type(:with).skip >>
          (at_least_one(implementation_function, separated_by: type(:comma).skip) | none.map { [] })
            .map { [it] } >>
          type(:end).skip
      )
        .map(&AST.implementation)
    end

    def implementation_function
      (
        (type(:identifier) | (type(:lparen).skip >> operator >> type(:rparen).skip)) >>
        type(:colon).skip >>
        (lambda | variable_reference)
      )
        .map(&AST.implementation_function)
    end

    def struct_declaration
      (
        type(:struct) >>
          constant >>
          (type_params | none.map { [[]] }) >>
          type(:assign).skip >> type_record
          
      ).map(&AST.struct_declaration)
    end

    def int
      type(:int).map(&AST.literal)
    end

    def float
      type(:float).map(&AST.literal)
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
  end
end
