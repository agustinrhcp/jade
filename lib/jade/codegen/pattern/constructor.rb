module Jade
  module Codegen
    module Pattern
      module Constructor
        extend self
        extend Helpers

        def generate(node, registry)
          node => AST::Pattern::Constructor(symbol:, patterns:)
          qualified = to_qualified(registry.lookup(symbol).qualified_name)

          patterns
            .map { generate_node(it, registry) }
            .join(', ')
            .then { it.empty? ? it : "(#{it})" }
            .then { "#{qualified}#{it}" }
        end
      end
    end
  end
end
