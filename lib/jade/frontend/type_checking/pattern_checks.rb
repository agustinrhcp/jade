module Jade
  module Frontend
    module TypeChecking
      # The coverage and redundancy of every `case` in a definition, decided
      # against the substitution inference ended with rather than the one in
      # scope where the patterns were written.
      module PatternChecks
        extend self

        def run(state)
          state
            .pattern_checks
            .flat_map { |(patterns, range, type)| errors_for(patterns, range, type, state.env) }
            .then { state.add_errors(it) }
        end

        private

        def errors_for(patterns, range, type, env)
          resolved = env.substitution.apply(type)

          [
            PatternAnalysis::Exhaustiveness.assert(patterns, range, env, resolved),
            PatternAnalysis::Redundancy.assert(patterns, env, resolved),
          ].flatten
        end
      end
    end
  end
end
