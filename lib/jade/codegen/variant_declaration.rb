module Jade
  module Codegen
    module VariantDeclaration
      extend self
      extend Helpers

      def generate(node, sibling_names)
        node => AST::VariantDeclaration(name:, args:, symbol:)

        impls = symbol.qualified_name
          .then { "::#{to_qualified(it)}" }
          .then { Codegen.dispatched_methods[it] || [] }

        sibling_names
          .map { |s| "def #{predicate_name(s)}; #{s == name}; end" }
          .then { [it.join(Pretty.newline), *impls] }
          .reject(&:empty?)
          .join(Pretty.newline(2))
          .then { Pretty.block("#{name} = #{data_define(fields_for(args))} do", it) }
      end

      private

      def fields_for(args)
        case args
        in [AST::TypeRecord(fields:)]
          fields.keys
        else
          args.map.with_index { |_, i| "_#{i + 1}" }
        end
      end

      def predicate_name(variant_name)
        variant_name
          .gsub(/([a-z])([A-Z])/, '\1_\2')
          .downcase
          .then { "#{it}?" }
      end
    end
  end
end
