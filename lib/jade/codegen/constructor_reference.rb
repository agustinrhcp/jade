module Jade
  module Codegen
    module ConstructorReference
      extend self
      extend Helpers

      def generate(node, registry)
        node => AST::ConstructorReference(symbol:)
        from_symbol(registry.lookup(symbol))
      end

      def from_symbol(symbol)
        qualified = to_qualified(symbol.qualified_name)
        symbol.args.empty? ? "#{qualified}[]" : "#{qualified}.method(:[])"
      end
    end
  end
end
