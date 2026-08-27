module Jade
  module Frontend
    module TypeChecking
      module Error
        class RecordAccessTypeMismatch  < TypeMismatch
          def message
            "Something is off with this record access, it expects #{naming[@expected]} " +
              "but found #{naming[@actual]}"
          end
        end
      end
    end
  end
end
