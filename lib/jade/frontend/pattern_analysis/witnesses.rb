module Jade
  module Frontend
    module PatternAnalysis
      # Maranget's witness generation: the patterns a match would need to add
      # to become exhaustive. An empty result means it already is.
      module Witnesses
        extend self

        def missing(matrix, env)
          return exhausted_columns(matrix) if matrix.types.empty?

          type = matrix.types.first

          return Matrix.empty if Signature.uninhabited?(type)
          return Matrix.wildcard(matrix.types) if matrix.empty?
          return expanded(matrix, env) if Signature.expandable?(type, env)

          heads = matrix.heads
          split = Signature.of(type, heads, env)

          return unmatched_column(matrix, env) unless split.touched_by?(heads)

          split
            .cases
            .reduce(Matrix.empty(matrix.types)) do |acc, kase|
              witnesses(matrix, kase, env, heads.any? { kase.matches?(it) })
                .then { acc.concat(it) }
            end
        end

        private

        def expanded(matrix, env)
          missing(matrix.expand(env), env)
        end

        def exhausted_columns(matrix)
          matrix.empty? ? Matrix[[[]], []] : Matrix.empty
        end

        # Nothing in this column narrows anything — a type with no cases to
        # enumerate, or one every row left open. Whatever is missing lives in
        # the columns after it.
        def unmatched_column(matrix, env)
          missing(matrix.default, env)
            .map { [Wildcard[]] + it }
            .with(types: matrix.types)
        end

        # A case the first column matches is explored by specializing on it.
        # One it never matches can only be missing as a whole, so its witnesses
        # come from the rows that would have covered it — the ones headed by a
        # wildcard. Recursing there instead of into the case is what keeps a
        # recursive type from expanding forever.
        def witnesses(matrix, kase, env, matched)
          return Matrix.empty if kase.arg_types.any? { Signature.uninhabited?(it) }

          found =
            if matched
              missing(matrix.specialize(kase), env)
                .map { [kase.witness(it.take(kase.arity))] + it.drop(kase.arity) }

            else
              missing(matrix.default, env)
                .map { [kase.witness(Array.new(kase.arity) { Wildcard[] })] + it }
            end

          found.with(types: matrix.types)
        end
      end
    end
  end
end
