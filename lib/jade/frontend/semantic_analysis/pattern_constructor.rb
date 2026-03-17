module Jade
  module Frontend
    module SemanticAnalysis
      module PatternConstructor
        extend self
        extend Helper

        def analyze(node, registry, scope, entry)
          node => AST::Pattern::Constructor(constructor:, patterns:, symbol: sym_ref)

          symbol = registry.lookup(sym_ref)

          if symbol.args.size != patterns.size
            return Error::ConstructorPatternArityMismatch
              .new(entry&.name, nil, constructor:, expected_arity: symbol.args.size, actual_arity: patterns.size)
              .then { Result[scope, [it]] }
          end

          analyze_many(patterns, registry, scope, entry)
        end
      end
    end
  end
end
