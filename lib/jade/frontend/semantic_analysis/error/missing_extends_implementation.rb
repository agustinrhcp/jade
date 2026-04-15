module Jade
  module Frontend
    module SemanticAnalysis
      module Error
        class MissingExtendsImplementation < Jade::Error
          def initialize(entry, span, interface:, type:, required_by:)
            super(entry:, span:)
            @interface   = interface
            @type        = type
            @required_by = required_by
          end

          def message
            "implements #{@required_by} extends #{@interface}: " \
              "#{@interface} is not implemented for #{@type}"
          end
        end
      end
    end
  end
end
