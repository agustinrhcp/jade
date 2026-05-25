require 'jade/ast/pretty_printer'
require 'jade/ast/nodes'

module Jade
  module AST
    extend self
    extend Nodes

    define(:Literal, :value)
    define(:CharLiteral, :value)
    define(:List, :items)
    define(:RecordLiteral, :fields)
    define(:RecordField, :key, :value)

    define(:RecordUpdate, :base, :fields)
    define(:RecordUpdateSugar, :field_key)
    define(:RecordAccessSugar, :field_key)

    define(:Assign, :pattern, :expression)
    define(:Bind, :pattern, :expression)
    define(:VariableReference, :name)
    define(:ConstructorReference, :name)

    define(:Module, :name, :exposing, :body)
    define(:Body, :expressions)

    define(:FunctionDeclaration, :name, :params, :return_type, :body)
    define(:FunctionDeclarationParam, :name, :type)
    define(:TypeDeclaration, :name, :type_params, :variants)
    define(:VariantDeclaration, :name, :args)
    define(:TypeParam, :name)
    define(:ImportDeclaration, :module_name, :as, :exposing)
    define(:StructDeclaration, :name, :type_params, :record_type)

    define(:ExposeAll)
    define(:ExposeNone)
    define(:ExposeList, :items)
    define(:ExposeValue, :name)
    define(:ExposeAs, :as)
    define(:ExposeType, :name)
    define(:ExposeTypeExpand, :name)

    define(:Lambda, :params, :body)

    define(:Grouping, :expression)
    define(:Tuple, :items)
    define(:InfixApplication, :left, :operator, :right)
    define(:InfixOperator, :value)

    define(:FunctionCall, :callee, :args, :infix, :dictionaries)
    define(:KeyedCall, :callee, :fields)
    define(:Placeholder)
    define(:MemberAccess, :target, :name)
    define(:QualifiedAccess, :target, :name)
    define(:RecordAccess, :target, :name)

    define(:TypeName, :type)
    define(:QualifiedTypeName, :path)
    define(:TypeVar, :type)
    define(:TypeApplication, :constructor, :args)
    define(:TypeFunction, :params, :return_type)
    define(:TypeRecord, :fields, :row_var)
    define(:TypeTuple, :items)
    define(:TypeUnit)

    define(:IfThenElse, :condition, :if_branch, :else_branch)
    define(:CaseOf, :expression, :branches)
    define(:CaseOfBranch, :pattern, :body)

    define(:InteropImportDeclaration, :module, :functions)
    define(:InteropModule, :name)
    define(:InteropFunction, :name, :type)

    define(:Implementation, :interface, :applied_type, :extends, :functions)
    define(:ImplementationFunction, :name, :fn)

    define(:InterfaceDeclaration, :name, :type_param, :functions)
    define(:InterfaceFunctionDecl, :name, :type)

    module Pattern
      extend self
      extend Nodes

      define(:Wildcard)
      define(:Literal, :literal)
      define(:Binding, :name)
      define(:Constructor, :constructor, :patterns)
      define(:Record, :fields)
      define(:RecordField, :name, :pattern)
      define(:Tuple, :patterns)
      define(:List, :patterns, :rest)
    end

    def string_literal
      ->(tokens) do
        tokens => [open, token, close]

        Literal[token.value, token.range.begin...close.range.end]
      end
    end

    def char_literal
      ->(token) { CharLiteral[token.value, token.range] }
    end

    def literal
      ->(token) do
        value =
          case token.type
          in :int   then token.value.to_i
          in :float then token.value.to_f
          in :bool  then token.value == 'True'
          end

        Literal[value, token.range]
      end
    end

    def assign
      ->((pattern_node, _assignment, expression_node)) do
        Assign[
          pattern_node,
          expression_node,
          pattern_node.range.begin...expression_node.range.end,
        ]
      end
    end

    def bind
      ->((pattern_node, _bind, expression_node)) do
        Bind[
          pattern_node,
          expression_node,
          pattern_node.range.begin...expression_node.range.end,
        ]
      end
    end

    def variable_reference
      ->(identifier) do
        VariableReference[
          identifier.value,
          identifier.range,
        ]
      end
    end


    def constructor_reference
      ->(constant) do
        ConstructorReference[
          constant.value,
          constant.range,
        ]
      end
    end

    def body
      ->(expressions) do
        if expressions.empty?
          Body[[], nil]

        else
          Body[
            expressions,
            expressions.first.range.begin...expressions.last.range.end,
          ]
        end
      end
    end

    def function_declaration
      ->(tokens) do
        tokens => [def_token, name, params_list, return_type, body]

        range_end = body.range&.end || return_type.range.end

        FunctionDeclaration.new(
          name: name.value,
          params: params_list.items,
          return_type:,
          body:,
          trailing_comma: params_list.trailing_comma,
          range: def_token.range.begin...range_end,
        )
      end
    end

    def function_declaration_param
      ->(tokens) do
        tokens => [name, type]

        FunctionDeclarationParam[
          name.value,
          type,
          name.range.begin...type.range.end,
        ]
      end
    end

    def type_name
      ->(token) do
        TypeName[token.value, token.range]
      end
    end

    def type_record
      ->((lbrace, row_var, fields_list, rbrace)) do
        TypeRecord.new(
          fields: fields_list.items.map { |(identifier, type)| [identifier.value, type] }.to_h,
          row_var:,
          trailing_comma: fields_list.trailing_comma,
          range: lbrace.range.begin...rbrace.range.end,
        )
      end
    end

    def qualified_type_name
      ->((first, *rest)) do
        constants = [first] + rest
        QualifiedTypeName[constants.map(&:value), constants.first.range.begin...constants.last.range.end]
      end
    end

    def type_var
      ->(token) do
        TypeVar[token.value, token.range]
      end
    end

    def type_application
      ->((constructor, args_list, rparen)) do
        TypeApplication.new(
          constructor:,
          args: args_list.items,
          trailing_comma: args_list.trailing_comma,
          range: constructor.range.begin...(rparen || constructor).range.end,
        )
      end
    end

    def type_function
      ->((params, return_type)) do
        case params
        in [TypeUnit => unit]
          TypeFunction[[], return_type, unit.range.begin...return_type.range.end]
        else
          TypeFunction[params, return_type, params.first.range.begin...return_type.range.end]
        end
      end
    end

    def infix_application
      ->(left, token_op, right) do
        InfixApplication[
          left,
          InfixOperator[token_op.value, token_op.range],
          right,
          left.range.begin...right.range.end,
        ]
      end
    end

    def function_call
      ->(callee, lparen, args_list, rparen) do
        FunctionCall.new(
          callee:,
          args: args_list.items,
          infix: false,
          dictionaries: [],
          trailing_comma: args_list.trailing_comma,
          range: lparen.range.begin...rparen.range.end,
        )
      end
    end

    def member_access
      ->(target, dot, name) do
        MemberAccess[
          target,
          name,
          dot.range.begin...name.range.end,
        ]
      end
    end

    def type_declaration
      ->((type_token, name, type_params_list, variants)) do
        TypeDeclaration.new(
          name: name.value,
          type_params: type_params_list.items,
          variants:,
          trailing_comma: type_params_list.trailing_comma,
          range: type_token.range.begin...variants.last.range.end,
        )
      end
    end

    def type_param
      ->(identifier) do
        TypeParam[identifier.value, identifier.range]
      end
    end

    def variant_declaration
      ->((name, args_list)) do
        VariantDeclaration.new(
          name: name.value,
          args: args_list.items,
          trailing_comma: args_list.trailing_comma,
          range: name.range.begin...(args_list.items.last || name).range.end,
        )
      end
    end

    def keyed_variant
      ->((lparen, fields, rparen)) do
        type_record.call([lparen, nil, fields, rparen])
          .then { Parsing::Combinators::CommaList.new(items: [it], trailing_comma: false) }
      end
    end

    def keyed_call
      ->(callee, lparen, fields_list, rparen) do
        KeyedCall.new(
          callee:,
          fields: fields_list.items,
          trailing_comma: fields_list.trailing_comma,
          range: lparen.range.begin...rparen.range.end,
        )
      end
    end

    def keyed_pattern
      ->(fields) do
        fields_list = Parsing::Combinators::CommaList.new(items: fields, trailing_comma: false)
        record_pattern.call([fields.first, fields_list, fields.last])
          .then { Parsing::Combinators::CommaList.new(items: [it], trailing_comma: false) }
      end
    end

    def import_declaration
      ->((import, module_parts, as, exposing)) do
        ImportDeclaration[
          module_parts.map(&:value).join('.'),
          as,
          exposing,
          import.range.begin...(module_parts.last.range.end),
        ]
      end
    end

    def module_
      ->((module_parts, exposing, body)) do
        Module[
          module_parts.map(&:value).join('.'),
          exposing,
          body,
          module_parts.first.range.begin...(body.expressions.last.range.end),
        ]
      end
    end

    def if_then_else
      ->((if_token, condition, if_branch, else_branch)) do
        IfThenElse[
          condition,
          if_branch,
          else_branch,
          if_token.range.begin...else_branch.range.end,
        ]
      end
    end

    def maybe_postfix_if
      ->((expr, condition, else_expr)) do
        next expr if condition.nil?

        IfThenElse[
          condition,
          Body.new(expressions: [expr], range: expr.range),
          Body.new(expressions: [else_expr], range: else_expr.range),
          expr.range.begin...else_expr.range.end,
        ]
      end
    end

    def case_of
      ->((case_token, expression, branches)) do
        CaseOf[
          expression,
          branches,
          case_token.range.begin...branches.last.range.end,
        ]
      end
    end

    def case_of_branch
      ->((of_token, pattern, body)) do
        CaseOfBranch[
          pattern,
          body,
          of_token.range.begin...(body.range.end),
        ]
      end
    end

    def wildcard_pattern
      ->(token) do
        Pattern::Wildcard[token.range]
      end
    end

    def placeholder
      ->(token) { Placeholder[token.range] }
    end

    def literal_pattern
      ->(literal) do
        Pattern::Literal[literal, literal.range]
      end
    end

    def binding_pattern
      ->(identifier) do
        Pattern::Binding[identifier.value, identifier.range]
      end
    end

    def constructor_pattern
      ->((constructor, patterns_list)) do
        Pattern::Constructor.new(
          constructor:,
          patterns: patterns_list.items,
          trailing_comma: patterns_list.trailing_comma,
          range: constructor.range.begin...(patterns_list.items.first&.range&.end || constructor.range.end),
        )
      end
    end

    def record_pattern
      ->((lbrace, fields_list, r_brace)) do
        Pattern::Record.new(
          fields: fields_list.items,
          trailing_comma: fields_list.trailing_comma,
          range: lbrace.range.begin...r_brace.range.end,
        )
      end
    end

    def record_field_pattern
      ->((identifier, _, pattern)) do
        Pattern::RecordField[
          identifier.value,
          pattern,
          identifier.range.begin...pattern.range.end,
        ]
      end
    end

    def tuple_pattern
      ->((lparen_token, first, rest_list, rparen_token)) do
        Pattern::Tuple.new(
          patterns: [first, *rest_list.items],
          trailing_comma: rest_list.trailing_comma,
          range: lparen_token.range.begin...rparen_token.range.end,
        )
      end
    end

    def list_pattern
      ->((lbrack, (patterns_list, tail), rbrack)) do
        Pattern::List.new(
          patterns: patterns_list.items,
          rest: tail,
          trailing_comma: patterns_list.trailing_comma,
          range: lbrack.range.begin...rbrack.range.end,
        )
      end
    end

    def grouping
      ->((lparen_token, expression, rparen_token)) do
        Grouping[
          expression,
          lparen_token.range.begin...rparen_token.range.end
        ]
      end
    end

    def tuple
      ->((lparen_token, first, rest_list, rparen_token)) do
        Tuple.new(
          items: [first, *rest_list.items],
          trailing_comma: rest_list.trailing_comma,
          range: lparen_token.range.begin...rparen_token.range.end,
        )
      end
    end

    def type_tuple
      ->((lparen_token, first, rest_list, rparen_token)) do
        TypeTuple.new(
          items: [first, *rest_list.items],
          trailing_comma: rest_list.trailing_comma,
          range: lparen_token.range.begin...rparen_token.range.end,
        )
      end
    end

    def lambda
      ->((lead_token, params_list, body, rbrace_token)) do
        Lambda.new(
          params: params_list.items,
          body:,
          trailing_comma: params_list.trailing_comma,
          range: lead_token.range.begin...rbrace_token.range.end,
        )
      end
    end

    def expose_none
      ->(_) do
        ExposeNone[nil]
      end
    end

    def expose_all
      ->(dot_dot) do
        ExposeAll[dot_dot.range]
      end
    end

    def expose_list
      ->(comma_list) do
        ExposeList.new(
          items: comma_list.items,
          trailing_comma: comma_list.trailing_comma,
          range: comma_list.items.first.range.begin...comma_list.items.last.range.end,
        )
      end
    end

    def expose_value
      ->((identifier)) do
        ExposeValue[identifier.value, identifier.range]
      end
    end

    def expose_type
      ->((constant)) do
        ExposeType[constant.value, constant.range]
      end
    end

    def expose_type_expand
      ->((constant)) do
        ExposeTypeExpand[constant.value, constant.range]
      end
    end

    def expose_as
      ->((constant)) do
        ExposeAs[constant.value, constant.range]
      end
    end

    def list
      ->((lbrack, items_list, rbrack)) do
        List.new(
          items: items_list.items,
          trailing_comma: items_list.trailing_comma,
          range: lbrack.range.begin...rbrack.range.end,
        )
      end
    end

    def record_literal
      ->((lbrace, fields_list, rbrace)) do
        RecordLiteral.new(
          fields: fields_list.items,
          trailing_comma: fields_list.trailing_comma,
          range: lbrace.range.begin...rbrace.range.end,
        )
      end
    end

    def record_field
      ->((key, value)) do
        RecordField[key.value, value, key.range.begin...value.range.end]
      end
    end

    def record_update
      ->((lbrace, variable_reference, _pipe, fields_list, rbrace)) do
        RecordUpdate.new(
          base: variable_reference,
          fields: fields_list.items,
          trailing_comma: fields_list.trailing_comma,
          range: lbrace.range.begin...rbrace.range.end,
        )
      end
    end

    def record_update_sugar
      ->((dot, key, _assign)) do
        RecordUpdateSugar[key.value, dot.range.begin...key.range.end]
      end
    end

    def record_access_sugar
      ->((dot, key)) do
        RecordAccessSugar[key.value, dot.range.begin...key.range.end]
      end
    end

    def interop_import_declaration
      ->((uses_token, interop_module, _with_token, interop_functions)) do
        InteropImportDeclaration[
          interop_module,
          interop_functions,
          uses_token.range.begin...interop_functions.last.range.end,
        ]
      end
    end

    def interop_module
      ->(parts) do
        InteropModule[
          parts.map(&:value).join('::'),
          parts.first.range.begin...parts.last.range.end,
        ]
      end
    end

    def interop_function
      ->((name, type_expression)) do
        InteropFunction[
          name.value,
          type_expression,
          name.range.begin...type_expression.range.end,
        ]
      end
    end

    def struct_declaration
      ->((struct_token, name, type_params_list, record_type)) do
        StructDeclaration.new(
          name: name.value,
          type_params: type_params_list.items,
          record_type:,
          trailing_comma: type_params_list.trailing_comma,
          range: struct_token.range.begin...record_type.range.end,
        )
      end
    end

    def implementation
      ->((implements_token, interface, applied_type, extends, functions)) do
        range_end = functions.last&.range&.end || applied_type.range.end
        Implementation[
          interface.value,
          applied_type,
          extends.map(&:value),
          functions,
          implements_token.range.begin...range_end,
        ]
      end
    end

    def implementation_function
      ->((name, fn)) do
        canonical_name = case name.type
                         in :identifier then name.value
                         else "(#{name.value})"
                         end

        ImplementationFunction[
          canonical_name,
          fn,
          name.range.begin...fn.range.end,
        ]
      end
    end

    def interface_declaration
      ->((interface_token, name, type_param, functions)) do
        InterfaceDeclaration[
          name.value,
          type_param,
          functions,
          interface_token.range.begin...functions.last.range.end,
        ]
      end
    end

    def interface_function_decl
      ->((name, type)) do
        canonical_name =
          case name.type
          in :identifier then name.value
          else "(#{name.value})"
          end

        InterfaceFunctionDecl[
          canonical_name,
          type,
          name.range.begin...type.range.end,
        ]
      end
    end
  end
end
