module Jade
  module Frontend
    module TypeChecking
      module Error
        class MissingPatterns < Jade::Error
          LISTED = 10

          def initialize(entry, span, missing_patterns:)
            @missing_patterns = missing_patterns
            super(entry:, span:)
          end

          def message
            "Pattern match is not exhaustive. Missing cases:\n#{listed}#{rest}"
          end

          def label
            "non-exhaustive pattern match"
          end

          private

          def listed
            @missing_patterns
              .take(LISTED)
              .map { |row| row.map(&:to_s).join(', ') }
              .map { "  #{it}" }
              .join("\n")
          end

          # A table split at every bound can leave hundreds of holes, and a
          # three-hundred-line error is not one anybody reads.
          def rest
            return '' if @missing_patterns.size <= LISTED

            "\n  … and #{@missing_patterns.size - LISTED} more"
          end
        end
      end
    end
  end
end
