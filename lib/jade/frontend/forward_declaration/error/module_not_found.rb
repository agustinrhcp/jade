module Jade
  module Frontend
    module ForwardDeclaration
      module Error
        class ModuleNotFound < Jade::Error
          def initialize(entry, span, name:)
            @name = name
            super(entry:, span:)
          end

          def message
            "Your are trying to import a module named `#{@name}` but I cannot find it"
          end
        end
      end
    end
  end
end
