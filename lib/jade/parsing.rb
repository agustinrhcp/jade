require 'jade/result'

require 'jade/parsing/combinators'
require 'jade/parsing/error'
require 'jade/parsing/token'
require 'jade/parsing/type'

module Jade
  module Parsing
    extend self
    include Combinators
    include Token
    include Type
    extend Combinators::Dsl

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

    def parse(tokens, entry:, parser: program)
      comments = tokens.select { it.type == :comment }

      parser
        .call(State.new(tokens: tokens.reject { it.type == :comment }, entry:))
        .map { [it.first, comments] }
        .map_error(&:first)
    end

    parser(:module_) {
      (
        type(:module).skip >>
        (
          module_name >>
          exposing >>
          program_body
        ).commit
      ).map(&AST.module_)
    }

    parser(:program) { module_ | program_body }

    parser(:program_body) { sequence(declaration | statement).map(&AST.body) }

    parser(:statement) { bind | assign | expression }

    parser(:declaration) {
      function_declaration | type_declaration | import_declaration | interop_import_declaration |
        struct_declaration | implementation | interface_declaration
    }

    parser(:expression) { case_of | if_then_else | lambda | infix_expression }

    parser(:tuple) {
      (
        type(:lparen) >>
          lazy { expression } >>
          type(:comma).skip >>
          comma_sequence(lazy { expression }) >>
          type(:rparen)
      ).map(&AST.tuple)
    }

    parser(:grouping) {
      (type(:lparen) >> lazy { expression } >> type(:rparen)).map(&AST.grouping)
    }

    parser(:infix_expression) {
      (primary >> many(operator >> primary))
        .map do |(head, *tail)|
          tail.reduce(head) do |left, (op, right)|
            AST.infix_application.call(left, op, right)
          end
        end
    }

    parser(:lambda) {
      (
        type(:lparen) >>
          (comma_sequence(assignment_pattern) | empty_comma_list) >>
          type(:rparen).skip >>
          type(:arrow).skip >>
          type(:lbrace).skip >>
          body >>
          type(:rbrace)
      ).map(&AST.lambda)
    }

    parser(:if_then_else) {
      (
        type(:if) >>
          lazy { expression } >>
          type(:then).skip >>
          body >>
          type(:else).skip >>
          body >>
          type(:end)
      ).map(&AST.if_then_else)
    }

    parser(:case_of) {
      (
        type(:case) >>
          lazy { expression } >>
          sequence(case_of_branch).map { [it] } >>
          type(:end)
      ).map(&AST.case_of)
    }

    parser(:case_of_branch) {
      (type(:of) >> pattern >> type(:then).skip >> body).map(&AST.case_of_branch)
    }

    parser(:pattern) {
      wildcard_pattern | list_pattern | literal_pattern | binding_pattern |
        constructor_pattern | tuple_pattern | record_pattern
    }

    parser(:tuple_pattern) {
      (
        type(:lparen) >>
          lazy { pattern } >>
          type(:comma).skip >>
          comma_sequence(lazy { pattern }) >>
          type(:rparen)
      ).map(&AST.tuple_pattern)
    }

    parser(:wildcard_pattern) { type(:wildcard).map(&AST.wildcard_pattern) }

    parser(:binding_pattern) { identifier.map(&AST.binding_pattern) }

    parser(:literal_pattern) { literal.map(&AST.literal_pattern) }

    parser(:constructor_pattern) {
      (constructor_reference >>
        ((type(:lparen).skip >>
        (keyed_pattern |
          comma_sequence(lazy { pattern }) |
          empty_comma_list) >>
        type(:rparen)) | empty_comma_list)
      ).map(&AST.constructor_pattern)
    }

    parser(:keyed_pattern) {
      sequence(record_field_pattern, separated_by: type(:comma).skip)
        .map(&AST.keyed_pattern)
    }

    parser(:record_pattern) {
      (
        type(:lbrace) >>
        comma_sequence(record_field_pattern) >>
        type(:rbrace)
      ).map(&AST.record_pattern)
    }

    parser(:record_field_pattern) {
      (
        (identifier >> type(:colon) >> lazy { pattern }) |
          (identifier >> type(:colon))
            .map { |identifier, colon| [identifier, colon, AST.binding_pattern.call(identifier)] }
      ).map(&AST.record_field_pattern)
    }

    parser(:body) { sequence(lazy { statement }).map(&AST.body) }

    parser(:operator) {
      type(:plus) | type(:minus) | type(:star) | type(:slash) |
        type(:pipe_forward) | type(:pipe_backward) | type(:eq) | type(:not_eq) |
        type(:lt) | type(:gt) | type(:lte) | type(:gte) | type(:andand) | type(:oror) |
        type(:plusplus)
    }

    parser(:primary) {
      (atom >> many(postfix))
        .map do |(node, *postfixes)|
          postfixes.reduce(node) do |acc, postfix_type|
            postfix_type.apply(acc)
          end
        end
    }

    parser(:negative_literal) {
      (type(:minus) >> (int | float)).map do |(minus_tok, lit_node)|
        lit_node.with(
          value: -lit_node.value,
          range: minus_tok.range.begin..lit_node.range.end,
        )
      end
    }

    parser(:atom) {
      variable_reference | negative_literal | literal | constructor_reference | tuple |
        grouping | record_literal | record_update_sugar | record_access_sugar | record_update
    }

    parser(:postfix) { function_call | member_access }

    parser(:module_name) {
      sequence(constant, separated_by: type(:dot).skip).map { [it] }
    }

    parser(:function_call) {
      (
        type(:lparen) >>
          (keyed_call |
            comma_sequence(function_call_arg) |
            empty_comma_list) >>
          type(:rparen)
      ).map { FunctionCallPostfix[*it] }
    }

    parser(:function_call_arg) { placeholder | lazy { expression } }

    parser(:keyed_call) {
      sequence(record_field, separated_by: type(:comma).skip)
        .map(&AST.keyed_call)
    }

    parser(:placeholder) { type(:wildcard).map(&AST.placeholder) }

    parser(:member_access) {
      (type(:dot) >> (variable_reference | constructor_reference))
        .map { MemberAccessPostfix[*it] }
    }

    parser(:import_declaration) {
      (
        type(:import) >>
          (
            module_name >>
            ((type(:as).skip >> constant).map(&AST.expose_as) | none.map { [nil] }) >>
            (exposing | none.map { [[]] })
          ).commit
      ).map(&AST.import_declaration)
       .context("import declaration")
    }

    parser(:exposing) {
      (type(:exposing).skip >>
          type(:lparen).skip >>
          (expose_list | expose_all) >>
          type(:rparen).skip
      ) | expose_none
    }

    parser(:expose_none) { none.map(&AST.expose_none) }

    parser(:expose_all) { type(:dotdot).map(&AST.expose_all) }

    parser(:expose_list) { comma_sequence(expose_item).map(&AST.expose_list) }

    parser(:expose_item) { expose_value | expose_type_expand | expose_type }

    parser(:expose_value) { identifier.map(&AST.expose_value) }

    parser(:expose_type_expand) {
      (constant >> type(:lparen) >> type(:dotdot) >> type(:rparen))
        .map(&AST.expose_type_expand)
    }

    parser(:expose_type) { constant.map(&AST.expose_type) }

    parser(:function_declaration) {
      (
        type(:def) >>
          (
            identifier >>
            type(:lparen).skip >>
            (comma_sequence(param) | empty_comma_list) >>
            type(:rparen).skip >>
            type(:arrow).skip >>
            type_expression >>
            sequence(statement).map(&AST.body) >>
            type(:end)
          ).commit
      ).map(&AST.function_declaration)
       .context("function declaration")
    }

    parser(:type_declaration) {
      (
        type(:type) >>
          (
            constant >>
            (type_params | empty_comma_list) >>
            type(:assign).skip >>
            sequence(variant_declaration, separated_by: type(:pipe).skip).map { [it] }
          ).commit
      ).map(&AST.type_declaration)
       .context("type declaration")
    }

    parser(:record_declaration) {
      (
        type(:data) >>
          constant >>
          (type_params | empty_comma_list) >>
          type(:assign).skip >>
          type_record
      ).map(&AST.record_declaration)
    }

    parser(:variant_declaration) {
      (
        constant >>
          (keyed_variant | type_expressions | empty_comma_list)
      ).map(&AST.variant_declaration)
    }

    parser(:keyed_variant) {
      (
        type(:lparen) >>
          type_record_fields >>
          type(:rparen)
      ).map(&AST.keyed_variant)
    }

    parser(:literal) { string | char | int | bool | float | list }

    parser(:list_pattern) {
      (
        type(:lbrack) >>
        (
          (
            comma_sequence(lazy { pattern }) >>
            (type(:pipe).skip >> lazy { pattern } | none)
          ) | (empty_comma_list >> none)
        ).map { [it] } >>
        type(:rbrack)
      ).map(&AST.list_pattern)
    }

    parser(:list) {
      (type(:lbrack) >>
        (comma_sequence(lazy { expression }) | empty_comma_list) >>
        type(:rbrack)
      ).map(&AST.list)
    }

    # Should refactor to just an Identifier node
    parser(:variable_reference) { identifier.map(&AST.variable_reference) }

    # Should refactor to just an Constant node
    parser(:constructor_reference) { constant.map(&AST.constructor_reference) }

    parser(:param) {
      (
        identifier >> type(:colon).skip >> type_expression
      ).map(&AST.function_declaration_param)
    }

    parser(:bind) {
      (
        assignment_pattern >>
          type(:bind) >>
          expression.commit
      ).map(&AST.bind)
    }

    parser(:assign) {
      (
        assignment_pattern >>
          type(:assign) >>
          expression.commit
      ).map(&AST.assign)
    }

    parser(:assignment_pattern) {
      wildcard_pattern | constructor_pattern | tuple_pattern | record_pattern |
        list_pattern | binding_pattern
    }

    # Records
    parser(:record_literal) {
      (type(:lbrace) >> record_fields >> type(:rbrace)).map(&AST.record_literal)
    }

    parser(:record_fields) { comma_sequence(record_field) }

    parser(:record_field) {
      (identifier >> type(:colon).skip >> lazy { expression }).map(&AST.record_field)
    }

    parser(:record_access_sugar) {
      (type(:dot) >> type(:identifier)).map(&AST.record_access_sugar)
    }

    parser(:record_update) {
      (type(:lbrace) >> variable_reference >> type(:pipe) >> record_fields >> type(:rbrace))
        .map(&AST.record_update)
    }

    parser(:record_update_sugar) {
      (type(:dot) >> type(:identifier) >> type(:assign)).map(&AST.record_update_sugar)
    }

    parser(:interop_import_declaration) {
      (
        type(:uses) >>
          (interop_module_name >> type(:with) >> interop_functions >> type(:end).skip)
            .commit
      ).map(&AST.interop_import_declaration)
       .context("interop import declaration")
    }

    parser(:interop_namespace_sep) { type(:coloncolon) }

    parser(:interop_module_name) {
      at_least_one(constant, separated_by: interop_namespace_sep.skip)
        .map(&AST.interop_module)
    }

    parser(:interop_functions) {
      at_least_one(interop_function, separated_by: type(:comma).skip)
        .map { [it] }
    }

    parser(:interop_function) {
      (identifier >> type(:colon).skip >> type_expression)
        .map(&AST.interop_function)
    }

    parser(:implementation) {
      (
        type(:implements) >>
          (
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
          ).commit
      ).map(&AST.implementation)
       .context("implementation")
    }

    parser(:interface_declaration) {
      (
        type(:interface) >>
          (
            type(:constant) >>
            type(:lparen).skip >>
            type_param >>
            type(:rparen).skip >>
            type(:with).skip >>
            (at_least_one(interface_function_decl, separated_by: type(:comma).skip) | none.map { [] })
              .map { [it] } >>
            type(:end).skip
          ).commit
      ).map(&AST.interface_declaration)
       .context("interface declaration")
    }

    parser(:interface_function_decl) {
      (
        (type(:identifier) | (type(:lparen).skip >> operator >> type(:rparen).skip)) >>
        type(:colon).skip >>
        type_expression
      ).map(&AST.interface_function_decl)
    }

    parser(:implementation_function) {
      (
        (type(:identifier) | (type(:lparen).skip >> operator >> type(:rparen).skip)) >>
        type(:colon).skip >>
        (lambda | variable_reference)
      )
        .map(&AST.implementation_function)
    }

    parser(:struct_declaration) {
      (
        type(:struct) >>
          (
            constant >>
            (type_params | empty_comma_list) >>
            type(:assign).skip >>
            type_record
          ).commit
      ).map(&AST.struct_declaration)
       .context("struct declaration")
    }

    parser(:int)   { type(:int).map(&AST.literal) }
    parser(:float) { type(:float).map(&AST.literal) }
    parser(:bool)  { type(:bool).map(&AST.literal) }
    parser(:char)  { type(:char).map(&AST.char_literal) }

    parser(:string) {
      (
        type(:quote) >>
          (type(:string_chunk) >> type(:quote))
            .commit
      )
        .map(&AST.string_literal)
    }
  end
end
