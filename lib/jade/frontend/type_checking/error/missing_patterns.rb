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
            patterns_str = @missing_patterns
              .map { |row| row.map(&:to_s).join(', ') }
              .map { "  #{it}" }
              .join("\n")
            "Pattern match is not exhaustive. Missing cases:\n#{patterns_str}"
          end

          def label
            "non-exhaustive pattern match"
          end
        end
      end
    end
  end
end
