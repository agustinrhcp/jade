module Jade
  module Frontend
    module ForwardDeclaration
      module TypeDeclaration
        extend self
        extend Helper

        def shallow(node, registry, entry)
          node => AST::TypeDeclaration(name:, type_params:, variants:)

          predeclared_variants = variants
            .map { |var| Symbol.predeclared_variant(var.name) }

          type_params.map(&:name).map { Symbol.var(it) }
            .then { Symbol.union(name, it, predeclared_variants) }
            .then { entry.define(it) }
            .then { Result[it, []] }
        end

        def deep(node, entry)
          node => AST::TypeDeclaration(name:, variants:)

          symbol = entry.lookup_type(name)

          variant_symbols = variants
            .map do |var|
              var
                .args
                .map { |arg| figure_out_type(entry, arg) }
                .then { Symbol.variant(var.name, it, symbol.to_ref) }
            end

          variant_symbols
            .reduce(entry) { |acc_entry, sym| acc_entry.define(sym) }
            .then { it.define(symbol.with(variants: variant_symbols.map(&:to_ref))) }
            .then { Result[it, []] }
        end
      end
    end
  end
end
