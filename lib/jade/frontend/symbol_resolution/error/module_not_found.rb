module Jade
  module Frontend
    module SymbolResolution
      module Error
        class ModuleNotFound < ::Error
          def initialize(entry, span, name:)
            @name = name
            super(entry:, span:)
          end

          def message
            "I cannot find a `#{@name}` module"
          end
        end
      end
    end
  end
end
