module Jade
  module Frontend
    module ForwardDeclaration
      module Error
        class AliasExpansion < Jade::Error
          def initialize(entry, span, name:)
            @name = name
            super(entry:, span:)
          end

          def message
            "`#{@name}` is a type alias, so `(..)` has nothing to expose; " \
              'an alias names a shape and has no constructors of its own'
          end

          def label
            "write `#{@name}` without `(..)`"
          end
        end
      end
    end
  end
end
