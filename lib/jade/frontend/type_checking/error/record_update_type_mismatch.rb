module Jade
  module Frontend
    module TypeChecking
      module Error
        # An update produces a record of its own, which then has to be the
        # record the surrounding code wanted. Changing a field's type is the
        # usual way to break that, and any other disagreement lands here too.
        class RecordUpdateTypeMismatch < TypeMismatch
          def message
            "This update produces #{naming.annotated(@actual)}, " \
              "but #{naming.annotated(@expected)} was expected"
          end

          def label
            "produces #{naming[@actual]}, expected #{naming[@expected]}"
          end
        end
      end
    end
  end
end
