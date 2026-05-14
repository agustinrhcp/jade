module Jade
  module Frontend
    module SymbolResolution
      module Error
        class ModuleNotFound < Jade::Error
          def initialize(entry, span, name:)
            @name = name
            super(entry:, span:)
          end

          def message
            "I cannot find a `#{@name}` module"
          end

          def label
            "not found"
          end
        end
      end
    end
  end
end
