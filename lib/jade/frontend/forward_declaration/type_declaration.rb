module Jade
  module Frontend
    module ForwardDeclaration
      module TypeDeclaration
        extend self
        extend Helper

        def shallow(node, registry, entry)
          node => AST::TypeDeclaration(name:, type_params:, variants:)

          duplicate_type_error(entry, name, node.range, declaring: 'a type')
            .then { return Result[entry, [it]] if it }

          # The type is still declared, so a signature naming it does not
          # report a second, misleading error.
          errors = duplicate_constructor_errors(entry, name, variants.map { [it.name, it.range] }, declaring: :variant)

          predeclared_variants = variants
            .map { |var| Symbol.predeclared_constructor(var.name, var.range) }

          type_params.map { Symbol.var(it.name, it.range) }
            .then { Symbol.union(name, it, predeclared_variants, node.range) }
            .then { entry.define(it) }
            .then { Result[it, errors] }
        end

        def deep(node, entry, _)
          node => AST::TypeDeclaration(name:, variants:)

          symbol = entry.lookup_type(name)

          return Result[entry, []] unless symbol.is_a?(Symbol::Union)

          variants
            .map do |var|
              var.args.map { figure_out_type(entry, it) }
                .then { Results.sequence(it) }
                .map { Symbol.constructor(var.name, it, symbol.to_ref, var.range) }
            end
            .then { Results.sequence(it) }
            .map do |variant_symbols|
              variant_symbols
                .reduce(entry) { |acc_entry, sym| acc_entry.define(sym) }
                .then { it.define(symbol.with(variants: variant_symbols.map(&:to_ref))) }
            end
            .then { to_declaration_result(entry, it) }
        end
      end
    end
  end
end
