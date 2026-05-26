module Jade
  module Codegen
    # Dynamically-scoped emission state. Each `with_X` wraps a block so the
    # state is visible to the recursive `generate` call tree, then restored
    # on exit. Stored on the Codegen singleton because threading these as
    # parameters through every AST branch would pollute the API.
    module Context
      extend self

      # Maps [interface_qname, type_var_id] => ruby parameter name. Set by
      # FunctionDeclaration around its body so nested calls can resolve the
      # caller's dict for var-typed constraints. Empty outside any function.
      def dict_env
        @dict_env ||= {}
      end

      def with_dict_env(env)
        prev = @dict_env
        @dict_env = env
        yield
      ensure
        @dict_env = prev
      end

      # When set, references with this name emit as `self` (and field accesses
      # on them as bare method calls). Used to rewrite operator-impl lambda
      # bodies — `(a, b) -> { a.amount == b.amount }` becomes
      # `def ==(b); amount == b.amount; end`, no `a = self` shim.
      #
      # Name-based, not symbol-identity-based, because Pattern::Binding doesn't
      # carry the resolved Symbol::Variable.
      def self_var_name
        @self_var_name
      end

      def with_self_var_name(name)
        prev = @self_var_name
        @self_var_name = name
        yield
      ensure
        @self_var_name = prev
      end

      # False outside a Module so bare expressions (REPL) get the runtime
      # fallback — no constants exist to reference.
      def hoist_records?
        @hoist_records
      end

      def with_hoisted_records
        prev = @hoist_records
        @hoist_records = true
        yield
      ensure
        @hoist_records = prev
      end

      # Methods (def strings) to inline into each type's `Data.define do ... end`
      # block. Populated once at the start of module emission by walking impls
      # of dispatched interfaces; consumed by StructDeclaration /
      # VariantDeclaration. Indexed by the fully-qualified Ruby class string
      # (e.g. `"::Sample::Money"`).
      def dispatched_methods
        @dispatched_methods || {}
      end

      def with_dispatched_methods(map)
        prev = @dispatched_methods
        @dispatched_methods = map
        yield
      ensure
        @dispatched_methods = prev
      end
    end
  end
end
