module Jade
  module Frontend
    module SemanticAnalysis
      module Error
        class TypeParamRequired < Jade::Error
          def initialize(entry, span, interface:, type:)
            super(entry:, span:)
            @interface = interface
            @type      = type
          end

          def message
            "#{@type} cannot implement #{@interface}: the type needs at least one type parameter"
          end
        end
      end
    end
  end
end
