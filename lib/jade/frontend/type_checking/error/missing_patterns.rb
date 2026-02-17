module Jade
  module Frontend
    module TypeChecking
      module Error
        class MissingPatterns < Jade::Error
          def initialize(entry, span, missing_patterns:)
            @missing_patterns = missing_patterns
            super(entry:, span:)
          end

          def message
            "Pattern is trying to match #{@expected} with #{@actual}"
          end
        end
      end
    end
  end
end
