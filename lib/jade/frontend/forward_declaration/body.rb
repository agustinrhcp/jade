module Jade
  module Frontend
    module ForwardDeclaration
      module Body
        extend self
        extend Helper

        def shallow(node, registry, entry)
          walk(node, entry) { |acc, expr| shallow_declare_node(expr, registry, acc) }
        end

        def deep(node, entry)
          walk(node, entry) { |acc, expr| deep_declare_node(expr, acc) }
        end

        private

        def walk(node, entry, &block)
          node => AST::Body(expressions:)

          expressions
            .reduce(Result[entry, []]) do |result, expression|
              yield(result.entry, expression)
                .add_errors(result.errors)
            end
        end
      end
    end
  end
end
