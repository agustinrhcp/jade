module Jade
  module Frontend
    module TypeChecking
      module Inference
        module Literal
          extend Helpers
          extend self

          def infer(node, registry, env, _)
            node => AST::Literal(symbol:)

            type_from_symbol(symbol, registry, env.var_gen)
              .then { Result.init(it, env) }
          end
        end
      end
    end
  end
end

