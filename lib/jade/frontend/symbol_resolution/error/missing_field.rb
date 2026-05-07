module Jade
  module Frontend
    module SymbolResolution
      module Error
        class MissingField < Jade::Error
          def initialize(entry, span, type_name:, fields:)
            @type_name = type_name
            @fields = fields
            super(entry:, span:)
          end

          def message
            list = @fields.map { "`#{it}:`" }.join(', ')
            "`#{@type_name}` is missing #{@fields.size == 1 ? 'field' : 'fields'} #{list}"
          end
        end
      end
    end
  end
end
