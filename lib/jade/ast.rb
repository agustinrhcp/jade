require 'jade/ast/pretty_printer'
require 'jade/ast/nodes'

module Jade
  module AST
    extend self
    extend Nodes

    define(:Literal, :value)
    define(:List, :items)

    define(:VariableBinding, :name, :expression)
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

    define(:ExposeAll)
    define(:ExposeNone)
    define(:ExposeList, :items)
    define(:ExposeValue, :name)
    define(:ExposeAs, :as)
    define(:ExposeType, :name)
    define(:ExposeTypeExpand, :name)

    define(:Lambda, :params, :body)
    define(:LambdaParam, :name)

    define(:Grouping, :expression)
    define(:InfixApplication, :left, :operator, :right)
    define(:InfixOperator, :value)

    define(:FunctionCall, :callee, :args)
    define(:MemberAccess, :target, :name)

    define(:TypeName, :type)
    define(:QualifiedTypeName, :path)
    define(:TypeVar, :type)
    define(:TypeApplication, :constructor, :args)
    define(:TypeFunction, :params, :return_type)

    define(:IfThenElse, :condition, :if_branch, :else_branch)
    define(:CaseOf, :expression, :branches)
    define(:CaseOfBranch, :pattern, :body)

    module Pattern
      extend self
      extend Nodes

      define(:Wildcard)
      define(:Literal, :literal)
      define(:Binding, :name)
      define(:Constructor, :constructor, :patterns)
    end

    def string_literal
      ->(tokens) do
        tokens => [open, token, close]

        Literal[token.value, token.range.begin..close.range.end]
      end
    end

    def literal
      ->(token) do
        value =
          case token.type
          in :int
            token.value.to_i

          in :bool
            token.value == 'True' ? true : false
          end

        Literal[value, token.range]
      end
    end

    def variable_binding
      ->(tokens) do
        tokens => [identifier, _assignment, expression_node]

        VariableBinding[
          identifier.value,
          expression_node,
          identifier.range.begin..expression_node.range.end,
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
            expressions.first.range.begin..expressions.last.range.end,
          ]
        end
      end
    end

    def function_declaration
      ->(tokens) do
        tokens => [def_token, name, param_nodes, return_type, body, end_token]

        FunctionDeclaration[
          name.value,
          param_nodes,
          return_type,
          body,
          def_token.range.begin...end_token.range.end,
        ]
      end
    end

    def function_declaration_param
      ->(tokens) do
        tokens => [name, type]

        FunctionDeclarationParam[
          name.value,
          type,
          name.range.begin..type.range.end,
        ]
      end
    end

    def type_name
      ->(token) do
        TypeName[token.value, token.range]
      end
    end

    def qualified_type_name
      ->((first, *rest)) do
        constants = [first] + rest
        QualifiedTypeName[constants.map(&:value), constants.first.range.begin..constants.last.range.end]
      end
    end

    def type_var
      ->(token) do
        TypeVar[token.value, token.range]
      end
    end

    def type_application
      ->((constructor, _lparen, args, rparen)) do
        TypeApplication[constructor, args, constructor.range.begin..rparen.range.end]
      end
    end

    def type_function
      ->((params, return_type)) do
        TypeFunction[params, return_type, params.first.range.begin..return_type.range.end]
      end
    end

    def infix_application
      ->(left, token_op, right) do
        InfixApplication[
          left,
          InfixOperator[token_op.value, token_op.range],
          right,
          left.range.begin..right.range.end,
        ]
      end
    end

    def function_call
      ->(callee, lparen, args, rparen) do
        FunctionCall[
          callee,
          args,
          lparen.range.begin..rparen.range.end,
        ]
      end
    end

    def member_access
      ->(target, dot, name) do
        MemberAccess[
          target,
          name,
          dot.range.begin..name.range.end,
        ]
      end
    end

    def type_declaration
      ->((type_token, name, type_params, variants)) do
        TypeDeclaration[
          name.value,
          type_params,
          variants,
          type_token.range.begin..variants.last.range.end,
        ]
      end
    end

    def type_param
      ->(identifier) do
        TypeParam[identifier.value, identifier.range]
      end
    end

    def variant_declaration
      ->((name, args)) do
        VariantDeclaration[
          name.value,
          args,
          name.range.begin..(args&.last || name).range.end,
        ]
      end
    end

    def import_declaration
      ->((import, module_parts, as, exposing)) do
        ImportDeclaration[
          module_parts.map(&:value).join('.'),
          as,
          exposing,
          import.range.begin..(module_parts.last.range.end),
        ]
      end
    end

    def module_
      ->((module_parts, exposing, body)) do
        Module[
          module_parts.map(&:value).join('.'),
          exposing,
          body,
          module_parts.first.range.begin..(body.expressions.last.range.end),
        ]
      end
    end

    def if_then_else
      ->((if_token, condition, if_branch, else_branch, end_token)) do
        IfThenElse[
          condition,
          if_branch,
          else_branch,
          if_token.range.begin..(end_token.range.end),
        ]
      end
    end

    def case_of
      ->((case_token, expression, branches, end_token)) do
        CaseOf[
          expression,
          branches,
          case_token.range.begin..(end_token.range.end),
        ]
      end
    end

    def case_of_branch
      ->((of_token, pattern, body)) do
        CaseOfBranch[
          pattern,
          body,
          of_token.range.begin..(body.range.end),
        ]
      end
    end

    def wildcard_pattern
      ->(token) do
        Pattern::Wildcard[token.range]
      end
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
      ->((constructor, patterns)) do
        Pattern::Constructor[
          constructor,
          patterns,
          constructor.range.begin..(patterns.first&.range&.end || constructor.range.end)
        ]
      end
    end

    def grouping
      ->((lparen_token, expression, rparen_token)) do
        Grouping[
          expression,
          lparen_token.range.begin..rparen_token.range.end
        ]
      end
    end

    def lambda
      ->((lparen_token, params, body, rbrace_token)) do
        Lambda[
          params,
          body,
          lparen_token.range.begin..rbrace_token.range.end,
        ]
      end
    end

    def lambda_param
      ->(identifier) do
        LambdaParam[identifier.value, identifier.range]
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
      ->((items)) do
        ExposeList[items, items.first.range.begin..items.last.range.end]
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
      ->((lbrack, items, rbrack)) do
        List[items, lbrack.range.begin..rbrack.range.end]
      end
    end
  end
end
