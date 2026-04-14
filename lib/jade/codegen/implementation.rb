module Jade
  module Codegen
    module Implementation
      extend self
      extend Helpers

      def generate(node, registry)
        node => AST::Implementation(interface:, applied_type:, functions:)

        type_name = applied_type.constructor.type
        functions
          .filter_map { generate_function(it, registry, interface, type_name) }
          .join("; ")
      end

      private

      def generate_function(impl_fn, registry, interface, type_name)
        impl_fn => AST::ImplementationFunction(name: fn_name, fn:)

        case fn
        in AST::Lambda
          fn_name = impl_synthetic_name(interface, type_name, fn_name)

          generate_node(fn, registry)
            .then { "def #{fn_name}; #{it}; end" }

        in AST::VariableReference
          nil
        end
      end
    end
  end
end
