module Jade
  module Frontend
    module SemanticAnalysis
      module Error
        class CircularExtends < Jade::Error
          def initialize(entry, span, interface:, type:)
            super(entry:, span:)
            @interface = interface
            @type      = type
          end

          def message
            "circular extends detected: #{@interface} for #{@type} is part of a cycle"
          end
        end
      end
    end
  end
end
