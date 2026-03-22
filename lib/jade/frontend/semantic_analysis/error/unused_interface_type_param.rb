module Jade
  module Frontend
    module SemanticAnalysis
      module Error
        class UnusedInterfaceTypeParam < Jade::Error
          def initialize(entry, span, interface:, type_param:)
            super(entry:, span:)
            @interface  = interface
            @type_param = type_param
          end

          def message
            "Interface `#{@interface}` declares type parameter `#{@type_param}` " \
              "but no function uses it: there is nothing to dispatch on"
          end
        end
      end
    end
  end
end
