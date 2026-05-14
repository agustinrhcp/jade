module Jade
  module Frontend
    module SymbolResolution
      module Error
        class ConstructorNotFound < Jade::Error
          def initialize(entry, span, name:)
            @name = name
            super(entry:, span:)
          end

          def message
            "I cannot find a `#{@name}` constructor"
          end

          def label
            "not found"
          end
        end
      end
    end
  end
end
