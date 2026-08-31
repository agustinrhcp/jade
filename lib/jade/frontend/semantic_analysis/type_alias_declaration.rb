require 'jade/frontend/semantic_analysis/type_alias_declaration/cycle_detection'

module Jade
  module Frontend
    module SemanticAnalysis
      module TypeAliasDeclaration
        extend self
        extend Helper

        def analyze(node, registry, scope, entry)
          node => AST::TypeAliasDeclaration(name:)

          symbol_ref = entry.lookup_type(name).to_ref

          Result
            .init(node.with(symbol: symbol_ref), scope)
            .add_errors(validate_no_unbound_vars(symbol_ref, registry, entry))
            .add_errors(validate_type_symbol(symbol_ref, registry, entry))
            .add_errors(CycleDetection.call(symbol_ref, registry, entry))
        end

        private

        def validate_no_unbound_vars(symbol_ref, registry, entry)
          actual_symbol = registry.lookup(symbol_ref)
          return [] unless actual_symbol.body

          missing = collect_vars(actual_symbol.body, registry)
            .group_by(&:name)
            .reject { |name, _| actual_symbol.type_params.map(&:name).include?(name) }
            .values
            .flatten

          return [] if missing.empty?

          [
            Error::UnboundTypeVariable.new(
              entry.name,
              missing.size == 1 ? missing.first.decl_span : actual_symbol.decl_span,
              type_name: symbol_ref.name,
              variables: missing.map(&:name).uniq,
            ),
          ]
        end
      end
    end
  end
end
