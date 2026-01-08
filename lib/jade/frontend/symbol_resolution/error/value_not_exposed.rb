module Jade
  module Frontend
    module SymbolResolution
      module Error
        class ValueNotExposed < Jade::Error
          def initialize(entry, span, name:, module_name:)
            @name = name
            @module_name = module_name
            super(entry:, span:)
          end

          def message
            "#{@module_name} does not a expose `#{@name}`"
          end
        end
      end
    end
  end
end
