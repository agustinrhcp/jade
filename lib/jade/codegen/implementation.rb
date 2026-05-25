module Jade
  module Codegen
    module Implementation
      extend self
      extend Helpers

      def generate(node, registry)
        node => AST::Implementation(symbol:)

        [
          generate_defs(node, registry),
          generate_registrations_for(node, registry),
          operator_impl_or_empty(node, registry, symbol.interface.qualified_name),
        ]
          .reject(&:empty?)
          .join(Pretty.newline(2))
      end

      def operator_impl_or_empty(node, registry, iface_qname)
        MethodNames.operator_interface?(iface_qname) \
          ? generate_operator_impl(node, registry)
          : ""
      end

      def generate_operator_impl(node, registry)
        node => AST::Implementation(functions:, symbol:)

        ruby_classes_for_type(symbol.type, registry).then { |ruby_classes|
          next "" if ruby_classes.empty?

          [
            *functions.filter_map { generate_operator_method(it, symbol, registry) },
            *comparable_derivations(symbol.interface.qualified_name),
          ]
            .then { it.empty? ? "" : class_reopens(ruby_classes, it) }
        }
      end

      def class_reopens(ruby_classes, method_defs)
        method_defs
          .join(Pretty.newline(2))
          .then { |body| ruby_classes.map { Pretty.block("class #{it}", body) } }
          .join(Pretty.newline(2))
      end

      def generate_operator_method(impl_fn, impl_sym, registry)
        impl_fn => AST::ImplementationFunction(name: fn_name, fn:)

        MethodNames
          .interface_method(impl_sym.interface.qualified_name, fn_name)
          &.then { |ruby_method| operator_method_body(ruby_method, fn, impl_sym, fn_name, registry) }
      end

      def operator_method_body(ruby_method, fn, impl_sym, fn_name, registry)
        case fn
        in AST::Lambda(params:, body:)
          return nil unless params.all? { simple_lambda_param?(it) }

          params
            .map { generate_node(it, registry) }
            .then { |(first, *rest)|
              ["#{first} = self", generate_node(body, registry)]
                .join(Pretty.newline)
                .then { Pretty.block("def #{ruby_method}(#{rest.join(', ')})", it) }
            }


        # Operator-interface fns are all binary, so `(other)` is the signature.
        in AST::VariableReference | AST::FunctionCall
          impl_sym
            .functions[fn_name]
            .then { it.is_a?(Symbol::ValueRef) ? it : nil }
            &.then { "::#{to_qualified(it.module_name)}::Internal.#{it.name}" }
            &.then { Pretty.block("def #{ruby_method}(other)", "#{it}(self, other)") }
        end
      end

      # `(Pepe(id), other) -> { ... }` would rebind a destructured pattern to
      # `self` — invalid Ruby. Fall back to the dispatch-table path.
      def simple_lambda_param?(pattern)
        pattern in AST::Pattern::Binding | AST::Pattern::Wildcard
      end

      COMPARABLE_DERIVATIONS = [
        "def <(other);  compare(other) in Jade::Basics::LT; end",
        "def >(other);  compare(other) in Jade::Basics::GT; end",
        "def <=(other); !(compare(other) in Jade::Basics::GT); end",
        "def >=(other); !(compare(other) in Jade::Basics::LT); end",
      ].freeze

      def comparable_derivations(iface_qname)
        iface_qname == 'Basics.Comparable' ? COMPARABLE_DERIVATIONS : []
      end

      def generate_defs(node, registry)
        node => AST::Implementation(interface:, applied_type:, functions:)

        type_name =
          case applied_type.constructor
          in AST::TypeName(type:) then type
          in AST::QualifiedTypeName(path:) then path.last
          end

        functions
          .filter_map { generate_function(it, registry, interface, type_name) }
          .join(Pretty.newline(2))
      end

      def generate_registrations_for(node, registry)
        node => AST::Implementation(symbol:)
        generate_registrations(symbol, registry)
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

        # Lambda thunk defers the `Internal.fn` lookup until call time —
        # register_impl runs at module load, before `Internal` is defined.
        fn_map = symbol.functions.filter_map { |fn_name, ref|
          next unless ref.is_a?(Symbol::ValueRef)

          [fn_name, "->(*args) { ::#{to_qualified(ref.module_name)}::Internal.#{ref.name}(*args) }"]
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
        in AST::Lambda(params:, body:)
          synth     = impl_synthetic_name(interface, type_name, fn_name)
          param_str = params.map { generate_node(it, registry) }.join(', ')
          sig       = param_str.empty? ? '' : "(#{param_str})"

          Pretty.block("def #{synth}#{sig}", generate_node(body, registry))

        # Bare VariableReference, and the auto-invoke FunctionCall the
        # desugar pass synthesises for zero-arg fn refs, both dispatch via
        # impl_fn_ref — no method emitted here.
        in AST::VariableReference | AST::FunctionCall
          nil
        end
      end
    end
  end
end
