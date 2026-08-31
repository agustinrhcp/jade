module Jade
  module Frontend
    module TypeChecking
      module Error
        class RangePatternType < PatternTypeMismatch
          def message
            "A range pattern only matches Int, and this one is matching " \
              "#{naming[@expected]}."
          end

          def label
            'range pattern on a type that is not Int'
          end

          def notes
            [
              Jade::Diagnostics::Annotation[
                :note,
                'Int is the only type a range covers checkably: 0..2 and ' \
                  '3..12 sit next to each other with nothing in between ' \
                  'them to be missed',
              ],
            ]
          end
        end
      end
    end
  end
end
