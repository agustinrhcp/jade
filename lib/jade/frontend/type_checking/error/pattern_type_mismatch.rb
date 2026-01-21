module Jade
  module Frontend
    module TypeChecking
      module Error
        class PatternTypeMismatch < TypeMismatch
          def message
            "Pattern is trying to match #{@expected} with #{@actual}"
          end
        end
      end
    end
  end
end
