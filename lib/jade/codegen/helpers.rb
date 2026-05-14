module Jade
  module Codegen
    module Helpers
      extend self

      def generate_many(nodes, registry, sep = ", ")
        nodes.map do
          next yield(it) if block_given?

          generate_node(it, registry)
        end.join(sep)
      end

      def to_qualified(module_name)
        base = module_name.gsub('.', '::')
        Stdlib.stdlib_name?(module_name) ? "Jade::#{base}" : base
      end

      def data_define(fields)
        return "Data.define" if fields.empty?

        "Data.define(#{fields.map { ":#{it}" }.join(', ')})"
      end

      def generate_node(node, registry)
        Codegen.generate(node, registry)
      end

      def resolve_callee_symbol(callee, registry)
        case callee.symbol
        in Symbol::ValueRef => ref then registry.lookup(ref)
        in symbol then symbol
        end
      end

      def param_synthetic_name(index)
        "__p#{index}__"
      end

      def impl_synthetic_name(interface, type_name, fn_name)
        sanitized = fn_name.gsub(/[^a-zA-Z0-9_]/) { |c| "x#{c.ord.to_s(16)}" }
        "__impl_#{interface}_#{type_name}_#{sanitized}__"
      end

      def dict_synthetic_name(index)
        "__dict#{index}__"
      end

      def fn_impl_synthetic_name(name)
        "__#{name}__impl__"
      end

      def fn_constraints(fn_symbol, registry)
        env = registry.get(fn_symbol.module_name).env

        env
          .bindings[fn_symbol.qualified_name]
          .constraints
          .map { env.substitution.apply(it) }
      end

      # Subset of fn_constraints that need a runtime dict param: those whose
      # type is a bare Type::Var. Other constraints (e.g. Eq(Maybe(α)) where α
      # is unbound but the outer constructor is concrete) are resolved at
      # finalize via the impl table — no dict threaded for them.
      def dict_constraints(fn_symbol, registry)
        fn_constraints(fn_symbol, registry).select { |c| c.type.is_a?(Type::Var) }
      end

      # Ruby classes that back primitive Jade types. Mirrors stdlib's
      # `native_type` declarations so user impls on primitives register under
      # the right Ruby class. (Lifting this onto Symbol::Union itself is
      # tracked in plans/lift-native-types-into-symbol-table.md.)
      NATIVE_RUBY_CLASSES = {
        'Basics.Int' => ['Integer'],
        'Basics.Float' => ['Float'],
        'Basics.Bool' => ['TrueClass', 'FalseClass'],
        'String.String' => ['String'],
        'Char.Char' => ['String'],
      }.freeze

      # Returns the Ruby class names that values of `type_ref` may have at
      # runtime. Strings here go straight into emitted Ruby. Returns [] for
      # types that have no concrete runtime representation (interfaces).
      def ruby_classes_for_type(type_ref, registry)
        qname = type_ref.qualified_name
        return NATIVE_RUBY_CLASSES[qname] if NATIVE_RUBY_CLASSES.key?(qname)

        case registry.lookup(type_ref)
        in Symbol::Union(variants:)
          variants.map { "::#{to_qualified(it.qualified_name)}" }

        in Symbol::Struct
          ["::#{to_qualified(qname)}"]

        in Symbol::Interface
          []
        end
      end

    def lower_to_ruby(value)
      case value
      in String
        value.dump

      in Array
        value
          .map { |v| lower_to_ruby(v) }.join(", ")
          .then { "[#{it}]" }

      in Hash
        value
          .map { |k, v| "#{lower_to_ruby(k)} => #{lower_to_ruby(v)}" }
          .join(", ")
          .then { "{ #{it}}" }
      end
    end
    end
  end
end
