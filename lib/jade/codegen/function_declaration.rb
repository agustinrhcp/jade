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

        # Two definitions for polymorphic fns: the public wrapper (boundary
        # calls — Ruby or runtime dispatch) computes the dict from the live
        # value; the impl-synthetic takes the dict as an arg so Jade-internal
        # callers can supply an inline dict and skip the lookup.
        "#{wrapper(name, param_names, var_cs, symbol, registry)}; #{impl_def}"
      end

      private

      def build_dict_env(var_cs)
        var_cs.each_with_index.with_object({}) do |(c, i), env|
          env[[c.interface, c.type.id]] = dict_synthetic_name(i)
        end
      end

      def wrapper(name, param_names, var_cs, symbol, registry)
        env = registry.get(symbol.module_name).env
        fn_type = env
          .substitution
          .apply(env.bindings[symbol.qualified_name].type)

        # No-arg fns collapse to their return type (Type.from_symbol_r drops
        # the Function wrapping). Any constraint on such a fn must reference
        # a return-position-only var, which the wrapper can't dispatch on.
        args = fn_type.is_a?(Type::Function) ? fn_type.args : []

        dict_lookups = var_cs
          .map do |c|
            dict_lookup_for(c, args, param_names, registry) ||
              unsupported_boundary_raise(symbol, c, args)
          end

        (param_names + dict_lookups)
          .join(', ')
          .then do
            "def #{name}; ->(#{param_names.join(', ')}) " \
              "{ #{fn_impl_synthetic_name(name)}.call(#{it}) }; end"
          end
      end

      def dict_lookup_for(c, args, param_names, registry)
        idx = args
          .index { it.unbound_vars.any? { |v| v.id == c.type.id } }

        return nil unless idx

        unbox(
          args[idx],
          c.type.id,
          param_names[idx],
          c.interface,
          registry,
          0,
        )
      end

      # Putting the raise inside the wrapper's lambda body (rather than at
      # codegen time) keeps Jade-internal callers working — they call the
      # impl-synthetic directly and never trigger this. Only Ruby boundary
      # calls hit the wrapper and get the error.
      def unsupported_boundary_raise(symbol, c, args)
        cause =
          if args.none? { it.unbound_vars.any? { |v| v.id == c.type.id } }
            "type variable #{c.type.name.inspect} does not appear in any argument " \
              "(return-position polymorphism — no value to dispatch on)"
          else
            arg = args.find { it.unbound_vars.any? { |v| v.id == c.type.id } }
            "argument of type #{arg} cannot be unboxed at the boundary " \
              "(function-typed args, anonymous records, and unsupported compound " \
              "shapes carry no extractable witness for #{c.type.name.inspect})"
          end

        Kernel.warn(
          "[jade] #{symbol.qualified_name} is not callable from Ruby: #{cause}. " \
            "The method is still defined but will raise on call."
        )

        "(raise ::Jade::Interop::NotCallableFromRuby.new(" \
          "#{symbol.qualified_name.inspect}, #{cause.inspect}))"
      end

      # Recursively walks the type of an arg that contains `var_id`,
      # emitting Ruby that destructures down to the var-typed value and
      # looks up its dict. `depth` keeps locally-bound names from
      # shadowing across nested case-ofs.
      #
      # Empty containers (`Nothing`, `[]`) and slots whose type doesn't
      # carry the var yield `{}` — the impl's branch for those values
      # must not consume the dict, which is the natural shape of bodies
      # that pattern-match before using the inner.
      def unbox(arg_type, var_id, expr, iface, registry, depth)
        case arg_type
        in Type::Var(id:) if id == var_id
          "Jade::Runtime.impl_for(#{iface.inspect}, #{expr})"

        in Type::Application(constructor: Type::Constructor(name: 'List.List'), args: [elem])
          unbox_list(elem, var_id, expr, iface, registry, depth)

        in Type::Application(constructor: Type::Constructor(name:), args:) if name.start_with?('Tuple.Tuple')
          unbox_tuple(name, args, var_id, expr, iface, registry, depth)

        in Type::Application(constructor: Type::Constructor(name:), args:)
          unbox_nominal(name, args, var_id, expr, iface, registry, depth)

        else
          nil
        end
      end

      def unbox_list(elem_type, var_id, expr, iface, registry, depth)
        head = "__head#{depth}__"
        inner = unbox(elem_type, var_id, head, iface, registry, depth + 1)

        "(case #{expr}; in [#{head}, *] then #{inner}; in [] then {}; end)"
      end

      def unbox_tuple(qname, app_args, var_id, expr, iface, registry, depth)
        slot = app_args.find_index { |t| t.unbound_vars.any? { |v| v.id == var_id } }
        return nil unless slot

        bound = "__slot#{depth}__"
        binders = app_args.each_index.map { |i| i == slot ? bound : '_' }
        inner = unbox(app_args[slot], var_id, bound, iface, registry, depth + 1)

        "(case #{expr}; in #{to_qualified(qname)}(#{binders.join(', ')}) then #{inner}; end)"
      end

      def unbox_nominal(qname, app_args, var_id, expr, iface, registry, depth)
        sym = registry.lookup(Symbol.type_ref_from_qualified_name(qname))

        case sym
        in Symbol::Union(variants:) if variants.any?
          unbox_union(sym, variants, app_args, var_id, expr, iface, registry, depth)

        in Symbol::Struct
          unbox_struct(sym, app_args, var_id, expr, iface, registry, depth)

        else
          nil
        end
      end

      def unbox_union(union, variant_refs, app_args, var_id, expr, iface, registry, depth)
        param_to_type = union.type_params
          .each_with_index
          .to_h { |tp, i| [tp.name, app_args[i]] }

        branches = variant_refs.map do |ref|
          variant_branch(registry.lookup(ref), param_to_type, var_id, iface, registry, depth)
        end

        "(case #{expr}; #{branches.join('; ')}; end)"
      end

      def variant_branch(variant, param_to_type, var_id, iface, registry, depth)
        qualified = to_qualified(variant.qualified_name)
        slot = variant.args.find_index do |arg|
          arg.is_a?(Symbol::Variable) &&
            param_to_type[arg.name]&.unbound_vars&.any? { |v| v.id == var_id }
        end

        return "in #{qualified} then {}" if slot.nil?

        bound = "__slot#{depth}__"
        binders = variant.args.each_index.map { |i| i == slot ? bound : '_' }
        inner = unbox(param_to_type[variant.args[slot].name], var_id, bound, iface, registry, depth + 1)

        "in #{qualified}(#{binders.join(', ')}) then #{inner}"
      end

      def unbox_struct(struct_sym, app_args, var_id, expr, iface, registry, depth)
        param_to_type = struct_sym.type_params
          .each_with_index
          .to_h { |tp, i| [tp.name, app_args[i]] }

        field_name, field_type_param = struct_sym.record_type.fields.find do |_, ft|
          ft.is_a?(Symbol::Variable) &&
            param_to_type[ft.name]&.unbound_vars&.any? { |v| v.id == var_id }
        end || [nil, nil]

        return nil unless field_name

        bound = "__field#{depth}__"
        inner = unbox(param_to_type[field_type_param.name], var_id, bound, iface, registry, depth + 1)
        qualified = to_qualified(struct_sym.qualified_name)

        "(case #{expr}; in #{qualified}(#{field_name}: #{bound}) then #{inner}; end)"
      end
    end
  end
end
