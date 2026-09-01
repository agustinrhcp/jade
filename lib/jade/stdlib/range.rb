require 'jade/stdlib/compiled'

module Jade
  module Stdlib
    module Range
      extend self
      extend Compiled

      def uri
        'range.jd'
      end

      def imports
        [Basics, Maybe, Tuple]
      end

      # `..` desugars to `Range.between`, so the module has to be in scope
      # wherever the operator is legal, which is everywhere.
      def default_imports
        [Symbol.type_ref('Range', 'Range')]
      end

      def code
        <<~JADE
          module Range exposing (
            Range,
            all,
            between,
            bounded?,
            clamp,
            contains?,
            empty,
            empty?,
            from,
            intersect,
            lower,
            overlaps?,
            to,
            upper,
          )

          type Range(a)
            = Empty
            | Between(a, a)
            | From(a)
            | To(a)
            | All


          def empty -> Range(a)
            Empty
          end


          def all -> Range(a)
            All
          end


          def from(low: a) -> Range(a)
            From(low)
          end


          def to(high: a) -> Range(a)
            To(high)
          end


          def between(low: a, high: a) -> Range(a)
            if low <= high then
              Between(low, high)
            else
              Empty
            end
          end


          def contains?(range: Range(a), value: a) -> Bool
            case range
            in Empty then False
            in Between(low, high) then low <= value && value <= high
            in From(low) then low <= value
            in To(high) then value <= high
            in All then True
            end
          end


          def empty?(range: Range(a)) -> Bool
            case range
            in Empty then True
            in Between(low, high) then high < low
            in From(_) then False
            in To(_) then False
            in All then False
            end
          end


          def bounded?(range: Range(a)) -> Bool
            case range
            in Empty then True
            in Between(_, _) then True
            in From(_) then False
            in To(_) then False
            in All then False
            end
          end


          def lower(range: Range(a)) -> Maybe(a)
            case range
            in Empty then Nothing
            in Between(low, _) then Just(low)
            in From(low) then Just(low)
            in To(_) then Nothing
            in All then Nothing
            end
          end


          def upper(range: Range(a)) -> Maybe(a)
            case range
            in Empty then Nothing
            in Between(_, high) then Just(high)
            in From(_) then Nothing
            in To(high) then Just(high)
            in All then Nothing
            end
          end


          def intersect(left: Range(a), right: Range(a)) -> Range(a)
            if empty?(left) || empty?(right) then
              Empty
            else
              rebuild(
                highest(lower(left), lower(right)),
                lowest(upper(left), upper(right)),
              )
            end
          end


          def overlaps?(left: Range(a), right: Range(a)) -> Bool
            intersect(left, right)
              |> empty?
              |> not
          end


          def clamp(range: Range(a), value: a) -> Maybe(a)
            if empty?(range) then
              Nothing
            else
              value
                |> at_least(lower(range))
                |> at_most(upper(range))
                |> Just
            end
          end


          def rebuild(low: Maybe(a), high: Maybe(a)) -> Range(a)
            case (low, high)
            in (Nothing, Nothing) then All
            in (Just(l), Nothing) then From(l)
            in (Nothing, Just(h)) then To(h)
            in (Just(l), Just(h)) then between(l, h)
            end
          end


          def highest(left: Maybe(a), right: Maybe(a)) -> Maybe(a)
            case (left, right)
            in (Nothing, _) then right
            in (_, Nothing) then left
            in (Just(l), Just(r)) then if l <= r then Just(r) else Just(l) end
            end
          end


          def lowest(left: Maybe(a), right: Maybe(a)) -> Maybe(a)
            case (left, right)
            in (Nothing, _) then right
            in (_, Nothing) then left
            in (Just(l), Just(r)) then if l <= r then Just(l) else Just(r) end
            end
          end


          def at_least(value: a, bound: Maybe(a)) -> a
            case bound
            in Nothing then value
            in Just(low) then if value <= low then low else value end
            end
          end


          def at_most(value: a, bound: Maybe(a)) -> a
            case bound
            in Nothing then value
            in Just(high) then if high <= value then high else value end
            end
          end
        JADE
      end
    end
  end
end
