module Jade
  module Frontend
    module TypeChecking
      module Error
        class PatternTypeMismatch < TypeMismatch
          def message
            "Pattern is trying to match #{naming[@expected]} with #{naming[@actual]}"
          end
        end
      end
    end
  end
end
