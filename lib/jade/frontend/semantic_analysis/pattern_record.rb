module Jade
  module Frontend
    module SemanticAnalysis
      module PatternRecord
        extend self
        extend Helper

        def analyze(node, registry, scope, entry)
          node => AST::Pattern::Record(fields:)

          symbol = Symbol
            .anonymous_record(fields.map(&:name), Symbol.var('a', nil))

          patterns_r = analyze_in_sequence(fields.map(&:pattern), registry, scope, entry)

          fields
            .zip(patterns_r.node)
            .map { |f, p| f.with(pattern: p) }
            .then { node.with(fields: it, symbol:) }
            .then { Result[it, patterns_r.errors, patterns_r.scope] }
        end
      end
    end
  end
end
