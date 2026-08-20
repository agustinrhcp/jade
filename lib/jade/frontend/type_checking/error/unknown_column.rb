module Jade
  module Frontend
    module TypeChecking
      module Error
        class UnknownColumn < Jade::Error
          def initialize(entry, span, struct:, field:, table:)
            @struct = struct
            @field = field
            @table = table
            super(entry:, span:)
          end

          def message
            "#{@struct}.#{@field} has no column on #{@table}"
          end

          def label
            "no column `#{@field}`"
          end
        end
      end
    end
  end
end
