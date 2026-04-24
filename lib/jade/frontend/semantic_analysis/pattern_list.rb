module Jade
  module Frontend
    module SemanticAnalysis
      module PatternList
        extend self
        extend Helper

        def analyze(node, registry, scope, entry)
          node => AST::Pattern::List(patterns:, rest:)

          result = analyze_many(patterns, registry, scope, entry)

          case rest
          in AST::Pattern::Binding(name:)
            bind(result.scope, Symbol.var(name, node.range), entry)
              .add_errors(result.errors)

          in AST::Pattern::Wildcard | nil
            result

          else
            Error::InvalidListRestPattern
              .new(entry.name, rest.range)
              .then { result.add_errors([it]) }
          end
        end
      end
    end
  end
end
