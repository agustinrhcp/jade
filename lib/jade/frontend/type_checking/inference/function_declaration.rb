module Jade
  module Frontend
    module TypeChecking
      module Inference
        module FunctionDeclaration
          extend Helpers
          extend self

          def infer(node, registry, state, _)
            node => AST::FunctionDeclaration(symbol:, body:, params:)

            fn_type = state.env.lookup(symbol.qualified_name)

            new_state, body_result = fn_type
              .args
              .zip(params)
              .reduce(state) do |acc, (t, p)|
                acc.bind(p.name, Scheme[[], t])
              end
              .then { check(body, registry, it, Expected.check(fn_type.return_type)) }

            new_state
              .unify(
                body_result.type,
                fn_type.return_type,
                fn_type.unbound_vars
              ) do
                Error::FunctionBodyTypeMismatch.new(
                  state.env.entry_name,
                  node.range,
                  expected: it.expected,
                  actual: it.actual,
                  function_name: node.name,
                )
              end
              .then { [it, Result.init(Type.unit)] }
          end
        end
      end
    end
  end
end
