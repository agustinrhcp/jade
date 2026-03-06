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

        in Symbol::Variant(module_name:, name:)
          to_qualified(module_name + "." + name) + ".method(:[])"

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
          [constraint.interface.qualified_name, name]
            .then { registry.implementations[it] }
            .functions
        end
      end
    end
  end
end
