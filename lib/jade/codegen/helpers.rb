module Jade
  module Codegen
    module Helpers
      extend self

      def generate_node(node, registry)
        Codegen.generate(node, registry)
      end
    end
  end
end
