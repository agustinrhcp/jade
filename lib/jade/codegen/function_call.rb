module Jade
  module Codegen
    module FunctionCall
      extend self
      extend Helpers

      def generate(node, registry)
        node => AST::FunctionCall(callee:, args:, dictionaries:)

        variant_sym = keyed_variant_constructor(callee, registry)
        return generate_keyed_variant_call(variant_sym, args, registry) if variant_sym

        try_operator_call(callee, args, registry)
          .then { return it if it }

        Inline.try_for(callee, args, dictionaries, registry)
          .then { return it if it }

        return constructor_call(callee, args, registry) if constructor_callee?(callee, registry)

        [generate_many(args, registry), generate_dict_args(callee, dictionaries, registry)]
          .reject(&:empty?)
          .join(', ')
          .then { "#{generate_callee(callee, args, registry, dictionaries)}#{invocation_op(callee, registry)}(#{it})" }
      end

      def constructor_call(callee, args, registry)
        resolve_callee_symbol(callee, registry)
          .then { to_qualified(it.qualified_name) }
          .then { "#{it}[#{generate_many(args, registry)}]" }
      end

      def constructor_callee?(callee, registry)
        return true if callee.is_a?(AST::ConstructorReference)

        resolve_callee_symbol(callee, registry).is_a?(Symbol::Constructor)
      end

      # Direct-def call sites (`Foo::Internal.name(args)`) for plain user fns;
      # `.call(args)` for everything else (lambdas, Procs, Methods).
      def invocation_op(callee, registry)
        case callee.symbol
        in Symbol::ValueRef => ref then invocation_op_for(registry.lookup(ref))
        in symbol                  then invocation_op_for(symbol)
        end
      end

      def invocation_op_for(symbol)
        symbol.is_a?(Symbol::Function) ? '' : '.call'
      end

      def try_operator_call(callee, args, registry)
        MethodNames
          .call_operator(callee_qname(callee, registry))
          &.then { |op| emit_operator(op, args, registry) }
      end

      def callee_qname(callee, registry)
        case resolve_callee_symbol(callee, registry)
        in Symbol::InterfaceFunction | Symbol::StdlibFunction => sym then sym.qualified_name
        else nil
        end
      end

      def emit_operator(op, args, registry)
        args
          .map { generate_node(it, registry) }
          .then { |(a, b)| op == 'compare' ? "#{a}.compare(#{b})" : "(#{a} #{op} #{b})" }
      end

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

      def dispatch_value(entry, registry)
        case entry
        in Type::Constraint(interface:, type: Type::Var(id:))
          Codegen.dict_env[[interface, id]]

        in Symbol::Implementation
          Pretty.hash(generate_impl_dispatch(entry, registry))
        end
      end

      # Polymorphic fn referenced as a value (not called). Wraps the fn with
      # its dispatched dictionaries so the result is a monomorphic callable
      # matching the type at the use site. Returns nil when the symbol
      # doesn't need wrapping; the caller falls back to its default
      # reference emission.
      def reference_with_dictionaries(symbol, dictionaries, registry)
        return nil if dictionaries.empty?

        case symbol
        in Symbol::StdlibFunction => fn if fn.constraints.any?
          dictionaries
            .map { dispatch_dict(it, registry) }
            .then { generate_impl_fn(fn.codegen, it, {}, registry) }

        in Symbol::Function => fn if dict_constraints(fn, registry).any?
          param_names = fn.params.size.times.map { param_synthetic_name(it) }

          fn_constraints(fn, registry)
            .each_with_index
            .filter_map { |c, i| dispatch_value(dictionaries[i], registry) if c.type.is_a?(Type::Var) }
            .then { (param_names + it).join(', ') }
            .then { "#{to_qualified(fn.module_name)}::Internal.#{fn_target_name(fn, registry)}(#{it})" }
            .then { Pretty.lambda(param_names.join(', '), it) }

        in Symbol::InterfaceFunction => fn
          dispatch_value(dictionaries.first, registry)
            &.then { "#{it}[#{fn.name.inspect}]" } ||
            fail("no dict in scope to reference interface method `#{fn.qualified_name}` as a value")

        else
          nil
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
        return generate_node(callee, registry) if callee in AST::RecordAccess | AST::FunctionCall | AST::Grouping

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
          to_qualified(fn_sym.module_name) + "::Internal." + fn_target_name(fn_sym, registry)

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

      # Ruby-block intrinsics (Dict's `Eq k`, etc.) ignore dispatches — the
      # `in String` body of `generate_impl_fn` drops them.
      def dispatch_dict(entry, registry)
        case entry
        in Symbol::Implementation
          generate_impl_dispatch(entry, registry)

        in Type::Constraint(interface:, type: Type::Var(id:))
          Codegen.dict_env[[interface, id]] ||
            fail("no dict in scope for #{interface}")
        end
      end

      # Generates a Ruby expression for `dict[fn_name]` from a dictionary entry.
      # Falls back to the supplied block when a var-typed marker has no entry
      # in the current dict_env (e.g. an anonymous lambda's body).
      def dispatch_lookup(entry, fn_name, registry, &fallback)
        case entry
        in Type::Constraint(interface:, type: Type::Var(id:))
          Codegen
            .dict_env[[interface, id]]
            &.then { "#{it}[#{fn_name.inspect}]" } || fallback.call

        in Symbol::Implementation
          generate_impl_dispatch(entry, registry)[fn_name]
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

        # Impl-dispatch dicts hold evaluated values, not callables —
        # `{ 'decoder' => <Decoder>, 'compare' => <Proc(a, b)> }`.
        # `impl_arg[i]['decoder'].desc` works directly; we never `.call`
        # it. So constant slots like `Decode.int` get invoked at synth
        # time; only multi-arg slots keep their Proc shape.
        #
        # The desugar pass that normally auto-invokes zero-arg refs
        # operates on AST. These dicts are built straight from
        # `Symbol::Implementation.functions` at codegen, no AST in
        # between, so the equivalent invoke happens here instead.
        in Symbol::StdlibFunction if fn.constant?
          "#{fn.codegen}.call()"

        in Symbol::StdlibFunction
          fn.codegen

        # Ruby-block intrinsic that declares a constraint for type-system
        # honesty but doesn't consume the dict at runtime (Dict ops use Ruby
        # `==`, etc.). The dispatches are dropped — the block sees only the
        # data args, same as the no-constraint path.
        in String
          fn

        in Symbol::StdlibImplementation
          sibling_dispatch = sibling_fns
            .reject { |_, sib| sib.is_a?(Symbol::StdlibImplementation) }
            .transform_values { |sib| generate_impl_fn(sib, dep_dispatches, sibling_fns, registry) }
          Pretty.lambda(fn.params.join(', '), build_std_impl_str(fn.body, sibling_dispatch, registry))

        in Symbol::ValueRef
          registry.lookup(fn).then { generate_impl_fn(it, dep_dispatches, sibling_fns, registry) }

        # 0-arg fn: Ruby auto-invokes on bare reference. Result is the
        # dispatch-slot value (decoder, encoder template, ...) ready to use.
        in Symbol::Function => fn if fn.constant?
          "#{to_qualified(fn.module_name)}::Internal.#{fn.name}"

        in Symbol::Function => fn
          "#{to_qualified(fn.module_name)}::Internal.method(:#{fn.name})"
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
