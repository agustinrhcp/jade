module Jade
  module Frontend
    module SemanticAnalysis
      module Error
        class OrphanImplementation < Jade::Error
          def initialize(entry, span, interface:, type:)
            super(entry:, span:)
            @interface = interface
            @type      = type
          end

          def message
            "Cannot implement #{@interface} for #{@type} here: " \
              "only the owner of the interface or the type can add implementations"
          end
        end
      end
    end
  end
end
