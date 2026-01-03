module Jade
  module Frontend
    module SymbolResolution
      module Pattern
        module Binding
          extend self

          def resolve(node, _, _)
            node => AST::Pattern::Binding

            Result[node, []]
          end
        end
      end
    end
  end
end
