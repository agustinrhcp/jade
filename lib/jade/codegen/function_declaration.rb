module Jade
  module Codegen
    module FunctionDeclaration
      extend self
      extend Helpers

      def generate(node, registry)
        node => AST::FunctionDeclaration(name:, params:, body:)

        generate_many(params, registry)
          .then { "def #{name}; ->(#{it}) { #{generate_node(body, registry)} }; end" }
      end
    end
  end
end
