module Jade
  module Frontend
    module SemanticAnalysis
      module StructDeclaration
        extend self
        extend Helper

        def analyze(node, registry, scope, entry)
          node => AST::StructDeclaration(name:)

          symbol_ref = entry.lookup_type(name).to_ref

          Result
            .init(node.with(symbol: symbol_ref), scope)
            .add_errors(validate_no_unbound_vars(symbol_ref, registry, entry))
            .add_errors(validate_type_symbol(symbol_ref, registry, entry))
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
              entry.name,
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
