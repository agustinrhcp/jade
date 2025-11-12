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
  end
end
