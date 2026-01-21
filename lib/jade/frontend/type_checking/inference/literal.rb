module Jade
  module Frontend
    module TypeChecking
      module Inference
        module Literal
          extend Helpers
          extend self

          def infer(node, registry, env, var_gen, _)
            node => AST::Literal(symbol:)

            type_from_symbol(symbol, registry, var_gen)
              .then { Result[it, Substitution.new, env, []] }
          end
        end
      end
    end
  end
end

