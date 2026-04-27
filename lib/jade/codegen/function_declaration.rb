module Jade
  module Codegen
    module FunctionDeclaration
      extend self
      extend Helpers

      def generate(node, registry)
        node => AST::FunctionDeclaration(name:, params:, body:)

        params_code = generate_many(params, registry)
        body_code   = generate_node(body, registry)

        "def #{name}; ->(#{params_code}) { #{body_code} }; end"
      end
    end
  end
end
