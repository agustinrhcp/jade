module Jade
  module Frontend
    module PatternAnalysis
      module Exhaustiveness
        extend self

        def assert(patterns, range, env, expected)
          Matrix[patterns.map { [Pattern.from_node(it)] }, [expected]]
            .then { Witnesses.missing(it, env) }
            .then { to_errors(it, range, env) }
        end

        private

        def to_errors(matrix, range, env)
          return [] if matrix.empty?

          TypeChecking::Error::MissingPatterns
            .new(env.entry_name, range, missing_patterns: matrix.rows)
            .then { [it] }
        end
      end
    end
  end
end
