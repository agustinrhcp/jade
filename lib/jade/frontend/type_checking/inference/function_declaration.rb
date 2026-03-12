# TODO: PLEASE MAKE ME BETTER.
module Jade
  module Frontend
    module TypeChecking
      module Inference
        module FunctionDeclaration
          extend Helpers
          extend self

          def infer(node, registry, env, _)
            node => AST::FunctionDeclaration(symbol:, body:, params:)

            # TODO: Need to fix pattern matching analysis before just checking
            # signatures at the end.
            # fn_type, constraints = env.lookup(symbol.qualified_name)
            # params_types = params.map { env.fresh(it.name) }

            entry = env.bindings[node.symbol.qualified_name]

            fn_type, constraints = instantiate(entry.signature, env.var_gen)

            body_r = fn_type
              .args
              .zip(params)
              .reduce(env) do |body_env, (t, p)|
                body_env.bind(p.name, Scheme.mono(t))
              end
              .then { check(body, registry, it, Expected.auth(fn_type.return_type)) }

            body_r = body_r
              .and_unify(fn_type.return_type.make_rigid, &type_error(env, node))
              # .then(&check_body_signature(env, node))

            if body_r.errors.empty?
              full_fn_type = Type.function(fn_type.args, body_r.type)
              body_r.tap { |r| entry.type = r.substitution.apply(full_fn_type) }
            end

            env
              .add_constraints!(constraints)
              .add_constraints!(body_r.constraints)

            body_r
              .then { it.with(type: Type.unit) }
          end

          private

          # def check_body_signature(env, node)
          #   ->(function_r) do
          #     entry = env.bindings[node.symbol.qualified_name]

          #     if entry.signature.nil? 
          #       function_r

          #     else
          #       sig_type, _ = instantiate(entry.signature, env)
          #       sig_return_type = sig_type.return_type.make_rigid

          #       body_r = function_r.with(type: function_r.type.return_type, errors: [])
          #       body_r.and_unify(sig_return_type, &type_error(env, node))
          #         .then { function_r.add_errors(it.errors) }
          #     end
          #   end
          # end

          def generalize_entry(entry)
            ->(fn_r) do
              byebug
              entry.type = fn_r.substitution.apply(entry.type)
            end
          end

          def type_error(env, node)
            ->(error) do
              Error::FunctionBodyTypeMismatch.new(
                env.entry_name,
                node.range,
                expected: error.expected,
                actual: error.actual,
                function_name: node.name,
              )
            end
          end
        end
      end
    end
  end
end
