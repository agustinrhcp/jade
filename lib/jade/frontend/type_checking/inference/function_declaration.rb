module Jade
  module Frontend
    module TypeChecking
      module Inference
        module FunctionDeclaration
          extend Helpers
          extend self

          def infer(node, registry, state, _)
            node => AST::FunctionDeclaration(symbol:, body:, params:)

            # fn_type = state.env.lookup_for_def(symbol.qualified_name) => { type: fn_type, constraints: fn_constraints }
            state.env.lookup(symbol.qualified_name) => { type: fn_type, constraints: fn_constraints }

            # puts fn_type.to_s if state.env.entry_name == '__Test__'
            new_state, body_result = fn_type
              .args
              .zip(params)
              .reduce(state) do |acc, (t, p)|
                acc.bind(p.name, Local[t])
              end
              .then { check(body, registry, it, Expected.auth(fn_type.return_type)) }
            # puts body_result.type.to_s if state.env.entry_name == '__Test__'
            # if state.env.entry_name == '__Test__'
            #   puts new_state.env.substitution.mappings.except(*state.env.substitution.mappings.keys).transform_values(&:to_s)
            #   puts body_result.constraints.map(&:to_s)
            #   # byebug
            # end

            new_state
              .unify(body_result.type, fn_type.return_type.make_rigid) do
                Error::FunctionBodyTypeMismatch.new(
                  state.env.entry_name,
                  node.range,
                  expected: it.expected,
                  actual: it.actual,
                  function_name: node.name,
                )
              end
              # .then { it.add_constraints_to_placeholder(symbol, body_result.constraints) }
              .then do |st|
                next st if st.env.bindings[symbol.qualified_name].is_a?(Scheme)
                st.bind(symbol.qualified_name, Placeholder[
                  # state.env.bindings[symbol.qualified_name].type,
                  fn_type,
                  (fn_constraints + body_result.constraints),#.map { st.env.substitution.apply(it) },
                ])
              end
              .then { [it, Result.init(Type.unit)] }
          end
        end
      end
    end
  end
end
