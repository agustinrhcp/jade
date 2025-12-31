require 'jade/ast/pretty_printer'

module Jade
  module AST
    extend self

    module Node
    end

    def define_ast_node(name, *fields)
      const_set(name, Data.define(*fields, :range, :symbol) {
        include Node

        define_method(:initialize) do |**kwargs|
          kwargs[:symbol] ||= nil
          super(**kwargs)
        end
      })
    end

    define_ast_node(:Literal, :value)

    define_ast_node(:VariableBinding, :name, :expression)
    define_ast_node(:VariableReference, :name)
    define_ast_node(:ConstructorReference, :name)

    define_ast_node(:Module, :name, :exposing, :body)
    define_ast_node(:Body, :expressions)

    define_ast_node(:FunctionDeclaration, :name, :params, :return_type, :body)
    define_ast_node(:FunctionDeclarationParam, :name, :type)
    define_ast_node(:TypeDeclaration, :name, :type_params, :variants)
    define_ast_node(:VariantDeclaration, :name, :args)
    define_ast_node(:TypeParam, :name)
    define_ast_node(:ImportDeclaration, :module_name, :exposing)

    define_ast_node(:InfixApplication, :left, :operator, :right)
    define_ast_node(:InfixOperator, :value)

    define_ast_node(:FunctionCall, :callee, :args)
    define_ast_node(:MemberAccess, :target, :name)

    define_ast_node(:TypeName, :type)
    define_ast_node(:TypeVar, :type)
    define_ast_node(:TypeApplication, :constructor, :args)

    define_ast_node(:IfThenElse, :condition, :if_branch, :else_branch)
    define_ast_node(:CaseOf, :expression, :branches)
    define_ast_node(:CaseOfBranch, :pattern, :body)

    module Pattern
      extend self

      def define_ast_node(name, *fields)
        const_set(name, Data.define(*fields, :range, :symbol) {
          include Node

          define_method(:initialize) do |**kwargs|
            kwargs[:symbol] ||= nil
            super(**kwargs)
          end
        })
      end

      define_ast_node(:Wildcard)
      define_ast_node(:Literal)
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

    def type_var
      ->(token) do
        TypeVar[token.value, token.range]
      end
    end

    def type_application
      ->(constructor, _lparen, args, rparen) do
        TypeVarVar[constructor, args, constructor.range.begin..rparen.range.end]
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
      ->((import, module_parts, exposing)) do
        ImportDeclaration[
          module_parts.map(&:value).join('.'),
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
      ->((pattern, body)) do
        CaseOfBranch[
          pattern,
          body,
          pattern.range.begin..(body.range.end),
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
  end
end
