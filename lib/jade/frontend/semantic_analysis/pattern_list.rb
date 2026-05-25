module Jade
  module Frontend
    module SemanticAnalysis
      module PatternList
        extend self
        extend Helper

        def analyze(node, registry, scope, entry)
          node => AST::Pattern::List(patterns:, rest:)

          patterns_r = analyze_in_sequence(patterns, registry, scope, entry)

          rest_scope, rest_errors =
            case rest
            in AST::Pattern::Binding(name:)
              bind_r = bind(patterns_r.scope, Symbol.var(name, node.range), entry)
              [bind_r.scope, bind_r.errors]

            in AST::Pattern::Wildcard | nil
              [patterns_r.scope, []]

            else
              [patterns_r.scope, [Error::InvalidListRestPattern.new(entry.name, rest.range)]]
            end

          Result
            .combine(node, scope: rest_scope, patterns: patterns_r)
            .add_errors(rest_errors)
        end
      end
    end
  end
end
