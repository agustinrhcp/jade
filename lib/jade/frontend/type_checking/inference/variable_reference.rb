module Jade
  module Frontend
    module TypeChecking
      module Inference
        module VariableReference
          extend Helpers
          extend self

          def infer(node, registry, env, var_gen, _)
            node => AST::VariableReference(symbol:)
        
            case symbol
            in Symbol::Variable
              env.bindings[symbol.name]
            else
              env.bindings[symbol.qualified_name]
            end
              .then { instantiate(it, var_gen) }
              .then { Result[it, Substitution.new, env, []] }
          end
        end
      end
    end
  end
end

