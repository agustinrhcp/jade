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
        in AST::ConstructorReference | AST::RecordAccess
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

        in Symbol::StdlibFunction | Symbol::DerivedFunction
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
            .reduce({}) { |acc, cons| acc.merge constraint_to_dispatch(cons, registry, callee) }

          generate_stdlib_implementation(callee, registry, dispatch)

        in Symbol::InterfaceFunction
          dispatch = dictionaries
            .reduce({}) { |acc, cons| acc.merge constraint_to_dispatch(cons, registry, callee) }

          sym = dispatch.fetch(callee.symbol.name) do
            case callee.symbol.name
            when "(==)" then Symbol::DerivedFunction["->(one, other) { one == other }"]
            when "(!=)" then Symbol::DerivedFunction["->(one, other) { one != other }"]
            end
          end

          callee.with(symbol: sym)
            .then { generate_callee(it, registry, dictionaries) }
        end
      end

      def constraint_to_dispatch(constraint, registry, callee)
        case constraint.type
        in Type::AnonymousRecord(fields:)
          eq_calls = fields
            .map do |(k, v)|
              field_sym = constraint_to_dispatch(constraint.with(type: v), registry, callee)["(==)"]
              field_code = generate_callee(callee.with(symbol: field_sym), registry, [])
              "#{field_code}.call(one[:#{k}], other[:#{k}])"
            end
            .join(' && ')

          {
            "(==)" => Symbol::DerivedFunction["->(one, other) { #{eq_calls} }"],
            "(!=)" => Symbol::DerivedFunction["->(one, other) { !(#{eq_calls}) }"],
          }

        in Type::Application(constructor: { name: })
          impl = registry.implementations[[constraint.interface, name]]

          if impl
            impl.functions

          else
            {
              "(==)" => Symbol::DerivedFunction["->(one, other) { one == other }"],
              "(!=)" => Symbol::DerivedFunction["->(one, other) { one != other }"],
            }
          end
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
            .then { generate_callee(it, registry, []) }

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
