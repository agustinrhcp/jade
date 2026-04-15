module Jade
  module Frontend
    module ForwardDeclaration
      module Error
        class UnknownExtendsInterface < Jade::Error
          def initialize(entry, span, interface:)
            @interface = interface
            super(entry:, span:)
          end

          def message
            "I cannot find an interface named `#{@interface}`"
          end
        end
      end
    end
  end
end
