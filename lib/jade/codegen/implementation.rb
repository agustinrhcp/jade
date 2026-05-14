module Jade
  module Codegen
    module Implementation
      extend self
      extend Helpers

      def generate(node, registry)
        node => AST::Implementation(symbol:, interface:, applied_type:, functions:)

        type_name = applied_type.constructor.type

        method_defs = functions
          .filter_map { generate_function(it, registry, interface, type_name) }
          .join(Pretty.newline(2))

        registrations = generate_registrations(symbol, registry)

        [method_defs, registrations].reject(&:empty?).join(Pretty.newline(2))
      end

      private

      # Emits Runtime.register_impl calls for each Ruby class that values of
      # the impl's type may have at runtime. The registered functions are
      # the impl's public wrappers — for impls on parameterised types like
      # `Encoder(Maybe(a))`, the wrapper does the inner-dict unboxing
      # internally (see FunctionDeclaration#wrapper), so dynamic dispatch
      # via threaded dicts lands in the right place.
      def generate_registrations(symbol, registry)
        ruby_classes = ruby_classes_for_type(symbol.type, registry)
        return "" if ruby_classes.empty?

        iface_qname = symbol.interface.qualified_name

        fn_map = symbol.functions.filter_map { |fn_name, ref|
          next unless ref.is_a?(Symbol::ValueRef)

          thunk = "->(*args) { ::#{to_qualified(ref.module_name)}.#{ref.name}.call(*args) }"
          [fn_name, thunk]
        }.to_h

        return "" if fn_map.empty?

        fn_map_str = Pretty.hash(fn_map)

        ruby_classes
          .map { "Jade::Runtime.register_impl(#{iface_qname.inspect}, #{it}, #{fn_map_str})" }
          .join(Pretty.newline)
      end

      def generate_function(impl_fn, registry, interface, type_name)
        impl_fn => AST::ImplementationFunction(name: fn_name, fn:)

        case fn
        in AST::Lambda
          fn_name = impl_synthetic_name(interface, type_name, fn_name)

          generate_node(fn, registry)
            .then { Pretty.block("def #{fn_name}", it) }

        in AST::VariableReference
          nil
        end
      end
    end
  end
end
