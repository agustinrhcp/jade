module Jade
  module AST
    extend self

    module Node
    end

    def define_ast_node(name, *fields)
      const_set(name, Data.define(*fields, :range) {
        include Node

        define_method(:initialize) do |**kwargs|
          super(**kwargs)
        end
      })
    end

    define_ast_node(:Literal, :value)

    def literal
      ->(token) do
        value =
          case token.type
          in :int
            token.value.to_i
          in :bool
          in :string
            token.value
          end

        Literal[value, token.range]
      end
    end
  end
end
