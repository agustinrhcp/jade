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
        case callee
        in AST::ConstructorReference(symbol:)
          return generate_node(callee, registry)
        else
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

        in Symbol::StdlibFunction(codegen:)
          codegen

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
            .reduce({}) { |acc, cons| acc.merge constraint_to_dispatch(cons, registry) }

          generate_stdlib_implementation(callee, registry, dispatch)

        in Symbol::InterfaceFunction
          dispatch = dictionaries
            .reduce({}) { |acc, cons| acc.merge constraint_to_dispatch(cons, registry) }
             
          dispatch[callee.symbol.name]
            .then { callee.with(symbol: it) }
            .then { generate_callee(it, registry, dictionaries) }
        end
      end

      def constraint_to_dispatch(constraint, registry)
        case constraint.type
        in Type::Application(constructor: { name: })
          [constraint.interface, name]
            .then { registry.implementations[it] }
            .functions
        end
      end

      def generate_stdlib_implementation(callee, registry, dispatch)
        callee
          .symbol
          .params
          .join(', ')
          .then { "->(#{it})" }
          .then { "#{it} { #{build_std_impl(callee, callee.symbol.body, registry, dispatch)} }" }
      end

      def build_std_impl(callee, body, registry, dispatch)
        case body
        in [:call, fn, args]
          args
            .map { build_std_impl(callee, it, registry, dispatch) }.join(', ')
            .then { "#{build_std_impl(callee, fn, registry, dispatch)}.call(#{it})" }

        in String
          body

        in [:impl, impl]
          dispatch[impl]
            .then { callee.with(symbol: it) }
            .then { generate_callee(it, registry, dispatch) }

        in [:fn, name]
          *mod_parts, fn_name = name.split('.')
          Symbol.value_ref(mod_parts.join('.'), fn_name)
            .then { callee.with(symbol: it) }
            .then { generate_callee(it, registry, dispatch) }
        end
      end
    end
  end
end
