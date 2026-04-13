module Jade
  module Frontend
    module SemanticAnalysis
      module Error
        class MissingImplementationFunction < Jade::Error
          def initialize(entry, span, interface:, fn_name:)
            super(entry:, span:)
            @interface = interface
            @fn_name   = fn_name
          end

          def message
            "Implementation of #{@interface} is missing required function `#{@fn_name}`"
          end
        end
      end
    end
  end
end
