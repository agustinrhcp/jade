module Jade
  module Frontend
    module TypeChecking
      module Inference
        module TypeDeclaration
          extend Helpers
          extend self

          def infer(node, registry, env, var_gen)
            node => AST::TypeDeclaration(symbol:, variants:)

            union_type = type_from_symbol(symbol, registry)

            type_from_symbol(symbol, registry)
              .then { env.bind(node.name, generalize(it)) }
              .then do
                variants.reduce(it) do |acc, variant|
                  acc.bind(variant.name, generalize(type_from_symbol(variant.symbol, registry)))
                end
              end
              .then do
                Result[Type.unit, Substitution.new, it, []]
              end
          end
        end
      end
    end
  end
end
