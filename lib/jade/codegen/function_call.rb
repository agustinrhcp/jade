module Jade
  module Codegen
    module FunctionCall
      extend self
      extend Helpers

      def generate(node, registry)
        node => AST::FunctionCall(callee:, args:, dictionaries:)

        variant_sym = keyed_variant_constructor(callee, registry)
        return generate_keyed_variant_call(variant_sym, args, registry) if variant_sym

        Inline.try_for(callee, args, dictionaries, registry)
          .then { return it if it }

        [generate_many(args, registry), generate_dict_args(callee, dictionaries, registry)]
          .reject(&:empty?)
          .join(', ')
          .then { "#{generate_callee(callee, args, registry, dictionaries)}.call(#{it})" }
      end

      # Public because PortDecoder needs it to emit a port's pre-resolved decoder.
      def generate_impl_dispatch(impl, registry)
        impl
          .deps
          .map { |dep| dispatch_for_dep(dep, registry) }
          .then do |dep_dispatches|
            impl.functions.transform_values do |fn|
              generate_impl_fn(fn, dep_dispatches, impl.functions, registry)
            end
          end
      end

      # An Implementation's dep is one of two dictionary-slot shapes: a
      # concrete Implementation (recurse to a `{fn_name => ruby_code}` hash)
      # or a Type::Constraint(Var) marker for a free-var dep that's late-bound
      # from the caller's dict env (emit the raw dict reference as a String —
      # build_impl_arg threads it into the impl_arg slot without re-wrapping).
      def dispatch_for_dep(dep, registry)
        case dep
        in Symbol::Implementation
          generate_impl_dispatch(dep, registry)

        in Type::Constraint(type: Type::Var)
          dispatch_value(dep, registry)
        end
      end

      # Resolves a dictionary entry (Symbol::Implementation or Type::Constraint)
      # to a Ruby expression evaluating to a dict hash. Public because
      # PortDecoder uses it to emit per-call decoder lookups for polymorphic
      # ports.
      def dispatch_value(entry, registry)
        case entry
        in Type::Constraint(interface:, type: Type::Var)
          Codegen.dict_env[[interface, canonical_var_id(entry.type)]]

        in Symbol::Implementation
          Pretty.hash(generate_impl_dispatch(entry, registry))
        end
      end

      private

      def keyed_variant_constructor(callee, registry)
        case resolve_callee_symbol(callee, registry)
        in Symbol::Constructor(args: [Symbol::RecordType]) => resolved
          resolved

        else
          nil
        end
      end

      def generate_keyed_variant_call(constructor, args, registry)
        qualified = to_qualified(constructor.qualified_name)
        record_fields = constructor.args[0].fields.keys

        args[0] => arg
        case arg
        in AST::RecordLiteral(fields:)
          fields_by_key = fields.to_h { [it.key, it.value] }
          record_fields
            .map { generate_node(fields_by_key.fetch(it), registry) }
            .join(', ')
            .then { "#{qualified}[#{it}]" }
        else
          "#{qualified}[**#{generate_node(arg, registry)}.to_h]"
        end
      end


      def generate_callee(callee, args, registry, dictionaries)
        return generate_node(callee, registry) if callee in AST::ConstructorReference | AST::RecordAccess | AST::FunctionCall | AST::Grouping

        case callee.symbol
        in Symbol::ValueRef
          registry
            .lookup(callee.symbol)
            .then { generate_callee(callee.with(symbol: it), args, registry, dictionaries) }

        in Symbol::InteropFunction
          registry
            .lookup(callee.symbol.to_ref)
            .then { PortDecoder.task_call(it, registry, dictionaries) }

        in Symbol::StdlibFunction => symbol if symbol.constraints.any?
          dictionaries
            .map { |entry| dispatch_dict(entry, registry) }
            .then { generate_impl_fn(symbol.codegen, it, {}, registry) }

        in Symbol::StdlibFunction
          callee.symbol.codegen

        in Symbol::Variable(name:)
          name

        in Symbol::Lambda
          generate_node(callee, registry)

        in Symbol::Function => fn_sym
          to_qualified(fn_sym.module_name) + "." + fn_target_name(fn_sym, registry)

        in Symbol::Constructor => sym
          ConstructorReference.from_symbol(sym)

        in Symbol::StdlibImplementation => symbol
          dictionaries
            .reduce({}) { |acc, entry| acc.merge dispatch_dict(entry, registry) }
            .then { generate_stdlib_implementation(symbol, registry, it) }

        in Symbol::InterfaceFunction => symbol if dictionaries.any?
          dispatch_lookup(dictionaries.first, symbol.name, registry) {
            runtime_dispatch(symbol, args, registry)
          }

        in Symbol::InterfaceFunction => symbol
          runtime_dispatch(symbol, args, registry)
        end
      end

      # When a user fn has var-typed constraints, two definitions are emitted:
      # `name` (Ruby-boundary wrapper, no dicts) and `__name__impl__` (takes
      # dicts). Jade-internal calls target the latter.
      def fn_target_name(fn_sym, registry)
        return fn_sym.name if dict_constraints(fn_sym, registry).empty?

        fn_impl_synthetic_name(fn_sym.name)
      end

      # Returns the list of dict args to pass after regular args. Only
      # Symbol::Function callees take dict params; other branches dispatch
      # via `dictionaries` directly inside generate_callee. dictionaries are
      # attached in callee constraint order; only var-typed slots need a
      # runtime dict (others are resolved at finalize).
      def generate_dict_args(callee, dictionaries, registry)
        symbol =
          case callee.symbol
          in Symbol::ValueRef then registry.lookup(callee.symbol)
          else callee.symbol
          end

        return "" unless symbol.is_a?(Symbol::Function)

        fn_constraints(symbol, registry)
          .each_with_index
          .filter_map { |c, i| dispatch_value(dictionaries[i], registry) if c.type.is_a?(Type::Var) }
          .join(', ')
      end

      # Returns a codegen-time hash of fn_name => ruby_code for the entry.
      # For Implementation, inlines functions. For a Var Constraint marker, we
      # can't enumerate fn names at compile time, so callers must use
      # dispatch_lookup instead.
      def dispatch_dict(entry, registry)
        case entry
        in Symbol::Implementation
          generate_impl_dispatch(entry, registry)
        end
      end

      # Generates a Ruby expression for `dict[fn_name]` from a dictionary entry.
      # Falls back to the supplied block when a var-typed marker has no entry
      # in the current dict_env (e.g. an anonymous lambda's body).
      def dispatch_lookup(entry, fn_name, registry, &fallback)
        case entry
        in Type::Constraint(interface:, type: Type::Var)
          Codegen
            .dict_env[[interface, canonical_var_id(entry.type)]]
            &.then { "#{it}[#{fn_name.inspect}]" } || fallback.call

        in Symbol::Implementation
          generate_impl_dispatch(entry, registry)[fn_name]
        end
      end

      def canonical_var_id(var)
        case Codegen.dict_substitution.apply(var)
        in Type::Var(id:) then id
        else var.id
        end
      end

      def runtime_dispatch(symbol, args, registry)
        generate_node(args.first, registry)
          .then { "Jade::Runtime.impl_for(#{symbol.interface.qualified_name.inspect}, #{it})[#{symbol.name.inspect}]" }
      end

      def generate_impl_fn(fn, dep_dispatches, sibling_fns, registry)
        case fn
        in Symbol::DerivedFunction(params:, body:)
          inner = params.empty? \
            ? emit(body, registry)
            : Pretty.lambda(params.join(', '), emit(body, registry))
          return inner if dep_dispatches.empty?

          Pretty.lambda("impl_arg", inner) + ".call(#{build_impl_arg(dep_dispatches)})"

        in Symbol::StdlibFunction if fn.params.empty?
          "#{fn.codegen}.call()"

        in Symbol::StdlibFunction
          fn.codegen

        in Symbol::StdlibImplementation
          sibling_dispatch = sibling_fns
            .reject { |_, sib| sib.is_a?(Symbol::StdlibImplementation) }
            .transform_values { |sib| generate_impl_fn(sib, dep_dispatches, sibling_fns, registry) }
          Pretty.lambda(fn.params.join(', '), build_std_impl_str(fn.body, sibling_dispatch, registry))

        in Symbol::ValueRef
          registry.lookup(fn).then { generate_impl_fn(it, dep_dispatches, sibling_fns, registry) }

        in Symbol::Function => fn if fn.params.empty?
          "#{to_qualified(fn.module_name)}.#{fn.name}.call()"

        in Symbol::Function => fn
          "#{to_qualified(fn.module_name)}.#{fn.name}"
        end
      end

      def build_impl_arg(dep_dispatches)
        dep_dispatches
          .map { it.is_a?(String) ? it : Pretty.hash(it) }
          .then { Pretty.array(it) }
      end

      # Stdlib intrinsics implementation language.

      def generate_stdlib_implementation(symbol, registry, dispatch)
        Pretty.lambda(symbol.params.join(', '), build_std_impl_str(symbol.body, dispatch, registry))
      end

      def build_std_impl_str(body, dispatch, registry)
        case body
        in [:call, fn, args]
          args.map { build_std_impl_str(it, dispatch, registry) }.join(', ')
            .then { "#{build_std_impl_str(fn, dispatch, registry)}.call(#{it})" }

        in String
          body

        in [:impl, impl]
          dispatch[impl]

        in [:fn, name]
          *mod_parts, fn_name = name.split('.')
          sym = Symbol.value_ref(mod_parts.join('.'), fn_name)
          registry.lookup(sym).then { generate_impl_fn(it, [], {}, registry) }
        end
      end

      def emit(ir, registry)
        Emitter.emit(ir)
      end
    end
  end
end
