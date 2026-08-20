module Jade
  module Frontend
    module TypeChecking
      module Error
        class ColumnTypeMismatch < Jade::Error
          def initialize(entry, span, struct:, field:, table:, column:, expected:, actual:)
            @struct = struct
            @field = field
            @table = table
            @column = column
            @expected = expected
            @actual = actual
            super(entry:, span:)
          end

          def message
            "#{@table}.#{@column} is #{@expected}, " \
              "but #{@struct}.#{@field} is #{@actual}"
          end

          def label
            "column is #{@expected}, field is #{@actual}"
          end
        end
      end
    end
  end
end
