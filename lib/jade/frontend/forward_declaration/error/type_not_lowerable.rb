module Jade
  module Frontend
    module ForwardDeclaration
      module Error
        class TypeNotLowerable < Jade::Error
          attr_reader :message

          def initialize(entry, span, message:)
            super(entry:, span:)
            @message = message
          end
        end
      end
    end
  end
end
