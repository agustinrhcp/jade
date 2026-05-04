module Jade
  module Codegen
    module VariantDeclaration
      extend self
      extend Helpers

      def generate(node)
        node => AST::VariantDeclaration(name:, args:)
        args
          .map.with_index { |_, i| "_#{i + 1}" }
          .then { data_define(it) }
          .then { "#{name} = #{it}" }
      end
    end
  end
end
