module Jade
  module Frontend
    module ForwardDeclaration
      module Error
        class ExposedTypeNotFound < Jade::Error
          def initialize(entry, span, name:)
            @name = name
            super(entry:, span:)
          end

          def message
            "Your are trying to expose a type named `#{@name}` but I cannot find its definition"
          end
        end
      end
    end
  end
end
