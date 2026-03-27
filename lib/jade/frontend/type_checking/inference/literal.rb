module Jade
  module Frontend
    module TypeChecking
      module Inference
        module Literal
          extend Helpers
          extend self

          def infer(node, registry, state, _)
            node => AST::Literal(symbol:)

            type_from_symbol(symbol, registry, state.env.var_gen)
              .then { [state, Result.init(*it)] }
          end
        end
      end
    end
  end
end

