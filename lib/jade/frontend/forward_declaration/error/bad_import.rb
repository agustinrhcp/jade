module Jade
  module Frontend
    module ForwardDeclaration
      module Error
        class BadImport < Jade::Error
          def initialize(entry, span, name:, module_name:)
            @name = name
            @module_name = module_name
            super(entry:, span:)
          end

          def message
            "The `#{@module_name}` module does not expose `#{@name}`"
          end
        end
      end
    end
  end
end
