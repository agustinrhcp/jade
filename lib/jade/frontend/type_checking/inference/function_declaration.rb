module Jade
  module Frontend
    module TypeChecking
      module Inference
        module FunctionDeclaration
          extend Helpers
          extend self

          def infer(node, registry, state, _)
            node => AST::FunctionDeclaration(symbol:, body:, params:)

            # state.env.lookup_for_def(symbol.qualified_name) => {
            #   type: fn_type, constraints: fn_constraints,
            # }
            state.env.lookup(symbol.qualified_name) =>
              { type: fn_type, constraints: fn_constraints }

            args_state = fn_type
              .args
              .zip(params)
              .reduce(state) do |acc, (t, p)|
                acc.bind(p.name, Scheme.mono(t))
              end
            new_state, body_result = args_state
               .then { check(body, registry, it, Expected.auth(fn_type.return_type)) }

            new_state
              .unify(body_result.type, fn_type.return_type) do
              # .unify(body_result.type, fn_type.return_type.make_rigid) do
                Error::FunctionBodyTypeMismatch.new(
                  state.env.entry_name,
                  node.range,
                  expected: it.expected,
                  actual: it.actual,
                  function_name: node.name,
                )
              end
              .then do |st|
                st.bind(symbol.qualified_name, Placeholder[
                  st.env.substitution.apply(fn_type),
                  (fn_constraints + body_result.constraints).map { st.env.substitution.apply(it) },
                ])
              end
              .then { [it, Result.init(Type.unit)] }
          end
        end
      end
    end
  end
end
