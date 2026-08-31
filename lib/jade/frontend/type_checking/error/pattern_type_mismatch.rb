module Jade
  module Frontend
    module TypeChecking
      module Error
        # A pattern the checker could not make sense of. Coverage is a claim
        # about the patterns as written, so one of these silences it.
        module PatternProblem; end

        class PatternTypeMismatch < TypeMismatch
          include PatternProblem

          def message
            "Pattern is trying to match #{naming[@expected]} with #{naming[@actual]}"
          end
        end
      end
    end
  end
end
