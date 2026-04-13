module Jade
  module Frontend
    module SemanticAnalysis
      module Error
        class UnknownImplementationFunction < Jade::Error
          def initialize(entry, span, interface:, fn_name:)
            super(entry:, span:)
            @interface = interface
            @fn_name   = fn_name
          end

          def message
            "`#{@fn_name}` is not a function of interface #{@interface}"
          end
        end
      end
    end
  end
end
