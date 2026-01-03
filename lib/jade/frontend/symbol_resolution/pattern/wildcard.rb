module Jade
  module Frontend
    module SymbolResolution
      module Pattern
        module Wildcard
          extend self

          def resolve(node, _, _)
            node => AST::Pattern::Wildcard

            node
          end
        end
      end
    end
  end
end
