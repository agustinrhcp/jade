module Jade
  module Frontend
    module PatternAnalysis
      module Exhaustiveness
        extend self

        def assert(patterns, range, env, expected)
          Matrix[patterns.map { [Pattern.from_node(it)] }, [expected]]
            .then { Witnesses.missing(it, env) }
            .then { it.with(rows: coalesced(it.rows)) }
            .then { to_errors(it, range, env) }
        end

        private

        # Splitting a column cuts it at every bound any pattern mentions, so
        # one hole can come back as several touching pieces. Report the hole.
        def coalesced(rows)
          joined = rows
            .combination(2)
            .lazy
            .filter_map { |(left, right)| join(left, right)&.then { [left, right, it] } }
            .first

          return rows if joined.nil?

          joined => [left, right, combined]

          coalesced(rows - [left, right] + [combined])
        end

        def join(left, right)
          return if left.size != right.size

          differing = left.each_index.reject { left[it] == right[it] }

          return if differing.size != 1

          index = differing.first

          span(left[index], right[index])
            &.then { |joined| left.take(index) + [joined] + left.drop(index + 1) }
        end

        def span(left, right)
          case [left, right]
          in [Interval(from:, to: Integer => last), Interval(from: ^(last + 1), to:)]
            Interval[from, to]

          in [Constructor(constructor: name, args: left_args),
              Constructor(constructor: ^name, args: right_args)]
            join(left_args, right_args)&.then { Constructor[name, it] }

          else
            nil
          end
        end

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
