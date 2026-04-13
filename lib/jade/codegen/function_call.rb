module Jade
  module Codegen
    module FunctionCall
      extend self
      extend Helpers

      def generate(node, registry)
        node => AST::FunctionCall(callee:, args:, dictionaries:)

        args_code = generate_many(args, registry)

        "#{generate_callee(callee, registry, dictionaries)}.call(#{args_code})"
      end

      private

      def generate_callee(callee, registry, dictionaries)
        if callee in AST::ConstructorReference | AST::RecordAccess
          return generate_node(callee, registry) 
        end

        case callee.symbol
        in Symbol::ValueRef
          registry
            .lookup(callee.symbol)
            .then { generate_callee(callee.with(symbol: it), registry, dictionaries) }

        in Symbol::InteropFunction => symbol
          lower_to_ruby(symbol.expected_type)
            .then { "#{symbol.interop_module_name}, :#{symbol.name}, #{it}" }
            .then { "Jade::Runtime.guard(#{it})" }

        in Symbol::StdlibFunction => symbol if symbol.constraints.any?
          dictionaries
            .map { |impl| generate_impl_dispatch(impl, registry) }
            .then { generate_impl_fn(symbol.codegen, it, {}, registry) }

        in Symbol::StdlibFunction
          callee.symbol.codegen

        in Symbol::Variable(name:)
          name

        in Symbol::Lambda
          generate_node(callee, registry)

        in Symbol::Function(module_name:, name:)
          to_qualified(module_name) + "." + name

        in Symbol::Constructor(module_name:, name:)
          to_qualified(module_name + "." + name) + ".method(:[])"

        in Symbol::StdlibImplementation => symbol
          dispatch = dictionaries
            .reduce({}) { |acc, impl| acc.merge generate_impl_dispatch(impl, registry) }

          generate_stdlib_implementation(symbol, registry, dispatch)

        in Symbol::InterfaceFunction
          dispatch = dictionaries
            .reduce({}) { |acc, impl| acc.merge generate_impl_dispatch(impl, registry) }

          dispatch[callee.symbol.name]
        end
      end

      def generate_impl_dispatch(impl, registry)
        dep_dispatches = impl.deps.map { |dep| generate_impl_dispatch(dep, registry) }
        impl.functions.transform_values { |fn|
          generate_impl_fn(fn, dep_dispatches, impl.functions, registry)
        }
      end

      def generate_impl_fn(fn, dep_dispatches, sibling_fns, registry)
        case fn
        in Symbol::DerivedFunction(params:, body:)
          inner = "->(#{params.join(', ')}) { #{emit(body, registry)} }"
          return inner if dep_dispatches.empty?

          impl_arg = build_impl_arg(dep_dispatches)
          "->(impl_arg) { #{inner} }.call(#{impl_arg})"

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
