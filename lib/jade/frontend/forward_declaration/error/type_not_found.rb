module Jade
  module Frontend
    module ForwardDeclaration
      module Error
        class TypeNotFound < Jade::Error
          def initialize(entry, span, name:)
            @name = name
            super(entry:, span:)
          end

          def message
            "Type `#{@name}` is not defined"
          end

          def label
            "not found"
          end
        end
      end
    end
  end
end
