module Jade
  module Frontend
    module PatternAnalysis
      module Redundancy
        extend self

        def assert(patterns, env, expected)
          rows = patterns.map { [Pattern.from_node(it)] }

          rows
            .each_with_index
            .filter_map do |row, index|
              above = Matrix[rows.take(index), [expected]]

              next if Usefulness.useful?(above, row, env)

              TypeChecking::Error::UnreachableBranch
                .new(env.entry_name, patterns[index].range)
            end
        end
      end
    end
  end
end
