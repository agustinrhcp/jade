module Jade
  module Frontend
    module TypeChecking
      module Generalization
        extend self

        def generalize(env, type, constraints = [])
          # TODO: Make rigid is a hack
          # somethin like this would be better
          # state.with_rigid(fn_type.return_type.free_vars) do |st|
          # st.unify(body_result.type, fn_type.return_type) { ... }
          # end
          # where the vars are rigid just withing the block
          unrigid_type = type.make_rigid(false)
          (unrigid_type.unbound_vars + constraints.flat_map(&:unbound_vars))
            .to_set
            .to_a
            .then { it - env.free_vars }
            .then { Scheme[it, unrigid_type, constraints] }
        end
      end
    end
  end
end

