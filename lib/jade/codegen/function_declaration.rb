module Jade
  module Codegen
    module FunctionDeclaration
      extend self
      extend Helpers

      def generate(node, registry)
        node => AST::FunctionDeclaration(name:, params:, body:)

        params_code = params.map { generate_node(it, registry) }.join(', ')
        "def #{name}; ->(#{params_code}) { #{generate_node(body, registry)} }; end"
      end
    end
  end
end
