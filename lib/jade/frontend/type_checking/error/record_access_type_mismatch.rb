module Jade
  module Frontend
    module TypeChecking
      module Error
        class RecordAccessTypeMismatch  < TypeMismatch
          def message
            "Something is off with this record access, it expects #{@expected} " +
              "but found #{@actual}"
          end
        end
      end
    end
  end
end
