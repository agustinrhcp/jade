module Jade
  module Frontend
    module SemanticAnalysis
      module PatternConstructor
        extend self
        extend Helper

        def analyze(node, registry, scope, entry)
          node => AST::Pattern::Constructor(constructor:, patterns:)

          constructor_r = analyze_node(constructor, registry, scope, entry)
          symbol_ref = constructor_r.node.symbol&.to_ref

          if symbol_ref.nil?
            return Result.combine(node, scope:, constructor: constructor_r)
          end

          arity_errors = arity_mismatch_errors(
            registry.lookup(symbol_ref), patterns, constructor, node.range, entry,
          )
          patterns_r = analyze_in_sequence(patterns, registry, scope, entry)

          Result
            .combine(node, scope: patterns_r.scope,
              constructor: constructor_r,
              patterns: patterns_r,
            )
            .map_node { it.with(symbol: symbol_ref) }
            .add_errors(arity_errors)
        end

        private

        def arity_mismatch_errors(symbol, patterns, constructor, range, entry)
          return [] if symbol.args.size == patterns.size

          [Error::ConstructorPatternArityMismatch.new(
            entry.name, range,
            constructor:,
            expected_arity: symbol.args.size,
            actual_arity: patterns.size,
          )]
        end
      end
    end
  end
end
