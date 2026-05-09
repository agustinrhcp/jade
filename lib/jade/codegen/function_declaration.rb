module Jade
  module Codegen
    module FunctionDeclaration
      extend self
      extend Helpers

      def generate(node, registry)
        node => AST::FunctionDeclaration(name:, params:, body:, symbol:)

        var_cs      = dict_constraints(symbol, registry)
        param_names = params.map { generate_node(it, registry) }
        dict_params = var_cs.each_index.map { dict_synthetic_name(it) }

        body_code = registry
          .get(symbol.module_name)
          .env
          .substitution
          .then do |subs|
            build_dict_env(var_cs)
              .then { Codegen.with_dict_env(it, subs) { generate_node(body, registry) } }
          end

        target = var_cs.empty? ? name : fn_impl_synthetic_name(name)

        impl_def = (param_names + dict_params)
          .join(', ')
          .then { "def #{target}; ->(#{it}) { #{body_code} }; end" }

        return impl_def if var_cs.empty?

        # Public method takes only the user-facing args; dicts are looked up
        # via the runtime IMPLEMENTATIONS table on a parameter whose type is
        # the constrained var. Jade-internal callers go through the impl name
        # directly to skip the lookup.
        "#{wrapper(name, param_names, var_cs, symbol, registry)}; #{impl_def}"
      end

      private

      def build_dict_env(var_cs)
        var_cs.each_with_index.with_object({}) do |(c, i), env|
          env[[c.interface, c.type.id]] = dict_synthetic_name(i)
        end
      end

      def wrapper(name, param_names, var_cs, symbol, registry)
        env  = registry.get(symbol.module_name).env
        args = env.substitution
          .apply(env.bindings[symbol.qualified_name].type)
          .args

        dict_lookups = var_cs.map do |c|
          param_names[args.index { it.id == c.type.id }]
            .then { "Jade::Runtime.impl_for(#{c.interface.inspect}, #{it})" }
        end

        (param_names + dict_lookups)
          .join(', ')
          .then do
            "def #{name}; ->(#{param_names.join(', ')}) " \
              "{ #{fn_impl_synthetic_name(name)}.call(#{it}) }; end"
          end
      end
    end
  end
end
