module Jade
  module Frontend
    module TypeChecking
      module Inference
        module QualifiedAccess
          extend Helpers
          extend self

          def infer(node, registry, state, expected)
            node => AST::QualifiedAccess(symbol:)

            state.env.lookup(symbol.qualified_name)
              .then { Result.init(it) }
              .then { state.unify_result(it, expected.type) }
          end
        end
      end
    end
  end
end

