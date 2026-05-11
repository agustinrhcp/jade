module Jade
  module Codegen
    module FunctionCall
      extend self
      extend Helpers

      def generate(node, registry)
        node => AST::FunctionCall(callee:, args:, dictionaries:)

        variant_sym = keyed_variant_constructor(callee, registry)
        return generate_keyed_variant_call(variant_sym, args, registry) if variant_sym

        [generate_many(args, registry), generate_dict_args(callee, dictionaries, registry)]
          .reject(&:empty?)
          .join(', ')
          .then { "#{generate_callee(callee, args, registry, dictionaries)}.call(#{it})" }
      end

      # Turns a Symbol::Implementation into a `{fn_name => ruby_code}` hash by
      # walking its deps + functions. Public because PortDecoder needs it to
      # emit a port's pre-resolved decoder; otherwise an internal helper.
      def generate_impl_dispatch(impl, registry)
        dep_dispatches = impl
          .deps
          .map { |dep| generate_impl_dispatch(dep, registry) }

        impl
          .functions
          .transform_values do |fn|
            generate_impl_fn(fn, dep_dispatches, impl.functions, registry)
          end
      end

      private

      # If the callee resolves to a constructor whose single arg is a record
      # type, returns the resolved Symbol::Constructor. Used to emit
      # field-spread construction for keyed variants whose runtime class
      # carries the record fields directly.
      def keyed_variant_constructor(callee, registry)
        resolved =
          case callee.symbol
          in Symbol::ValueRef => ref then registry.lookup(ref)
          in symbol then symbol
          end

        case resolved
        in Symbol::Constructor(args: [Symbol::RecordType])
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
            .then { PortDecoder.task_call(it, registry) }

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

      # Resolves a dictionary entry (Symbol::Implementation or Type::Constraint)
      # to a Ruby expression evaluating to a dict hash.
      def dispatch_value(entry, registry)
        case entry
        in Type::Constraint(interface:, type: Type::Var)
          Codegen.dict_env[[interface, canonical_var_id(entry.type)]]

        in Symbol::Implementation
          generate_impl_dispatch(entry, registry)
            .map { |k, v| "#{k.inspect} => #{v}" }
            .join(', ')
            .then { "{ #{it} }" }
        end
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
            : "->(#{params.join(', ')}) { #{emit(body, registry)} }"
          return inner if dep_dispatches.empty?

          impl_arg = build_impl_arg(dep_dispatches)
          "->(impl_arg) { #{inner} }.call(#{impl_arg})"

        in Symbol::StdlibFunction if fn.params.empty?
          "#{fn.codegen}.call()"

        in Symbol::StdlibFunction
          fn.codegen

        in Symbol::StdlibImplementation
          sibling_dispatch = sibling_fns
            .reject { |_, sib| sib.is_a?(Symbol::StdlibImplementation) }
            .transform_values { |sib| generate_impl_fn(sib, dep_dispatches, sibling_fns, registry) }
          params = fn.params.join(', ')
          body = build_std_impl_str(fn.body, sibling_dispatch, registry)
          "->(#{params}) { #{body} }"

        in Symbol::ValueRef
          registry.lookup(fn).then { generate_impl_fn(it, dep_dispatches, sibling_fns, registry) }

        in Symbol::Function => fn if fn.params.empty?
          "#{to_qualified(fn.module_name)}.#{fn.name}.call()"

        in Symbol::Function => fn
          "#{to_qualified(fn.module_name)}.#{fn.name}"
        end
      end

      def build_impl_arg(dep_dispatches)
        entries = dep_dispatches.map { |dispatch|
          fns = dispatch.map { |fn_name, code| "#{fn_name.inspect} => #{code}" }.join(', ')
          "{ #{fns} }"
        }
        "[#{entries.join(', ')}]"
      end

      # Stdlib intrinsics implementation language.

      def generate_stdlib_implementation(symbol, registry, dispatch)
        symbol
          .params
          .join(', ')
          .then { "->(#{it})" }
          .then { "#{it} { #{build_std_impl_str(symbol.body, dispatch, registry)} }" }
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
