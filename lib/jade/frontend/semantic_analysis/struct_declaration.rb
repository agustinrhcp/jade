module Jade
  module Frontend
    module SemanticAnalysis
      module StructDeclaration
        extend self
        extend Helper

        def analyze(node, registry, scope, entry)
          node => AST::StructDeclaration(symbol:)

          unbound_var_errors = validate_no_unbound_vars(symbol, registry, entry)
          annotation_errors = validate_type_symbol(symbol, registry, entry)

          Result[scope, unbound_var_errors + annotation_errors]
        end

        private

        def validate_no_unbound_vars(symbol, registry, entry)
          actual_symbol = registry.lookup(symbol)

          missing_vars = collect_vars(actual_symbol.record_type, registry)
            .group_by(&:name)
            .reject { |(k, _)| actual_symbol.type_params.map(&:name).include? k }
            .values
            .flatten

          return [] if missing_vars.empty?

          [
            Error::UnboundTypeVariable.new(
              entry&.name,
              missing_vars.size == 1 ? missing_vars.first.decl_span : actual_symbol.decl_span,
              type_name: symbol.name,
              variables: missing_vars.map(&:name),
            )
          ]
        end
      end
    end
  end
end
