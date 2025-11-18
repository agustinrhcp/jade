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

    define_ast_node(:Body, :expressions)

    define_ast_node(:FunctionDeclaration, :name, :params, :return_type, :body)
    define_ast_node(:FunctionDeclarationParam, :name, :type)
    define_ast_node(:TypeReference, :type, :args)

    define_ast_node(:InfixApplication, :left, :operator, :right)
    define_ast_node(:InfixOperator, :value)

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

    def body
      ->(expressions) do
        if expressions.size == 1
          expressions.first

        elsif expressions.size == 0
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

    def type_reference
      ->(token) do
        TypeReference[token.value, [], token.range]
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
  end
end
