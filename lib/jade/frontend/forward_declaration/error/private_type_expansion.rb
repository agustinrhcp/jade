module Jade
  module Frontend
    module ForwardDeclaration
      module Error
        class PrivateTypeExpansion < Jade::Error
          def initialize(entry, span, name:, module_name:)
            @name = name
            @module_name = module_name
            super(entry:, span:)
          end

          def message
            "#{@module_name}'s `#{@name}` type does not allow `(..)` because its constructors are private"
          end
        end
      end
    end
  end
end
