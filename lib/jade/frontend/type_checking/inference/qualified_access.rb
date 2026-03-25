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
              .then { state.unify_result(it, expected.type) do |error|
                  Error::RecordAccessTypeMismatch.new(
                    state.env.entry_name,
                    node.range,
                    expected: error.expected,
                    actual: error.actual,
                  )
                end
               }
          end
        end
      end
    end
  end
end

