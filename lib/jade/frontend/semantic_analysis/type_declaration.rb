module Jade
  module Frontend
    module SemanticAnalysis
      module TypeDeclaration
        extend self
        extend Helper

        def analyze(node, registry, scope, entry)
          node => AST::TypeDeclaration(name:, variants:)

          symbol_ref = entry.lookup_type(name).to_ref

          analyze_in_parallel(variants, registry, scope, entry)
            .then { Result.combine(node, scope:, variants: it) }
            .map_node { it.with(symbol: symbol_ref) }
            .add_errors(validate_no_unbound_vars(symbol_ref, registry, entry))
            .add_errors(validate_type_symbol(symbol_ref, registry, entry))
        end

        private

        def validate_no_unbound_vars(symbol, registry, entry)
          actual_symbol = registry.lookup(symbol)

          vars = actual_symbol
            .variants
            .flat_map { collect_vars(it, registry) }
            .group_by(&:name)

          missing_vars = vars
            .reject { |(k, _)| actual_symbol.type_params.map(&:name).include? k }
            .values
            .flatten

          return [] if missing_vars.empty?

          [
            Error::UnboundTypeVariable.new(
              entry.name,
              missing_vars.size == 1 ? missing_vars.first.decl_span : actual_symbol.decl_span,
              type_name: symbol.name,
              variables: missing_vars.map(&:name),
            )
          ]
        end

        def collect_vars(symbol, registry)
          case symbol
          in Symbol::TypeRef | Symbol::ValueRef
            registry.lookup(symbol)
              .then { collect_vars(it, registry) }

          in Symbol::Constructor(args:)
            args.flat_map { collect_vars(it, registry) }

          in Symbol::Variable
            [symbol]

          in Symbol::TypeApplication(args:)
            args.flat_map { collect_vars(it, registry) }

          in Symbol::RecordType(row_var:)
            row_var.nil? ? [] : [row_var]
          end
        end
      end
    end
  end
end
