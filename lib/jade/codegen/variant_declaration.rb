module Jade
  module Codegen
    module VariantDeclaration
      extend self
      extend Helpers

      def generate(node, sibling_names)
        node => AST::VariantDeclaration(name:, args:)

        fields = args.map.with_index { |_, i| "_#{i + 1}" }

        sibling_names
          .map { |s| "def #{predicate_name(s)}; #{s == name}; end" }
          .join('; ')
          .then { "#{name} = #{data_define(fields)} do; #{it}; end" }
      end

      private

      def predicate_name(variant_name)
        variant_name
          .gsub(/([a-z])([A-Z])/, '\1_\2')
          .downcase
          .then { "#{it}?" }
      end
    end
  end
end
