module Jade
  module Frontend
    module PatternAnalysis
      module Exhaustiveness
        extend self

        def assert(patterns, range, env, registry, expected)
          Matrix[
            patterns.map { [node_to_matrix_pattern(it)] },
            [expected],
          ]
            .missing_patterns(env)
            .then { to_errors(it, range, env) }
        end

        private

        def to_errors(matrix, range, env)
          return [] if matrix.empty?

          TypeChecking::Error::MissingPatterns
            .new(env.entry_name, range, missing_patterns: matrix.rows)
            .then { [it] }
        end

        def node_to_matrix_pattern(pattern_node)
          case pattern_node
          in AST::Pattern::Record(fields:)
            Record[
              fields
                .map(&:name)
                .zip(fields.map(&:pattern))
                .to_h
                .transform_values { node_to_matrix_pattern(it) },
            ]

          in AST::Pattern::Constructor(constructor:, patterns:)
            Constructor[
              constructor.symbol.qualified_name,
              patterns.map { node_to_matrix_pattern(it) },
            ]

          in AST::Pattern::List(patterns:, rest:)
            # Rewrite [x, y | xs] / [x, y] into nested Cons/Nil constructors
            tail = rest ? Wildcard[] : Constructor['List.Nil', []]
            patterns
              .map { node_to_matrix_pattern(it) }
              .reverse
              .reduce(tail) { |acc, head| Constructor['List.Cons', [head, acc]] }

          in AST::Pattern::Binding | AST::Pattern::Wildcard
            Wildcard[]

          in AST::Pattern::Literal(literal: { value:, symbol: })
            Literal[
              value,
              symbol.qualified_name,
            ]

          end
        end
      end
    end
  end
end
