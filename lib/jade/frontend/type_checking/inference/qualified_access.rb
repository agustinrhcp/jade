module Jade
  module Frontend
    module TypeChecking
      module Inference
        module QualifiedAccess
          extend Helpers
          extend self

          def infer(node, registry, env, _)
            node => AST::QualifiedAccess(symbol:)

            type_from_symbol(symbol, registry, env.var_gen)
              .then { Result[it, Substitution.new, env, []] }
          end
        end
      end
    end
  end
end

