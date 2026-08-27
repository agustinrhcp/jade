require 'set'

module Jade
  module Frontend
    module TypeChecking
      # One mistake is met by every node above it, each reporting it in
      # whatever type the one below left behind. Only the first is news.
      module Cascade
        extend self

        def prune(errors)
          errors
            .then { one_view_per_span(it) }
            .then { drop_downstream(it) }
        end

        private

        # Parent and child, reporting one unification failure. A subclass
        # of TypeMismatch exists to say more, so it is the one to keep.
        def one_view_per_span(errors)
          errors
            .chunk_while { |a, b| a.span && a.span == b.span }
            .flat_map { |group| mismatches?(group) ? [most_specific(group)] : group }
        end

        def mismatches?(group)
          group.size > 1 && group.all? { it.is_a?(Error::TypeMismatch) }
        end

        def most_specific(group)
          group
            .each_with_index
            .min_by { |error, i| [-depth(error.class), i] }
            .first
        end

        def depth(klass)
          klass.ancestors.take_while { it != Jade::Error }.size
        end

        # That variable is the hole the first failure left, so anything
        # naming it fails for the same reason.
        def drop_downstream(errors)
          errors
            .reduce([[], ::Set.new]) do |(kept, seen), error|
              vars = inference_vars(error)

              next [kept, seen] if vars.any? { seen.include?(it) }

              [kept + [error], seen | vars]
            end
            .first
        end

        # Two errors mentioning the author's `a` are not thereby the same
        # error; only inference's own variables mark a shared failure.
        def inference_vars(error)
          return ::Set.new unless error.is_a?(Error::TypeMismatch)

          [error.expected, error.actual]
            .compact
            .flat_map(&:unbound_vars)
            .select { it.name.nil? }
            .map(&:id)
            .to_set
        end
      end
    end
  end
end
