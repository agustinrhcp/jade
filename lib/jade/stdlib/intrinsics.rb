require 'jade/runtime'
require 'jade/symbol'

module Jade
  module Stdlib
    module Intrinsics
      def generate_entry(registry)
        @entry = entry
          .then { load_env(it, registry) }
      end

      def variant(name, of:, args: [])
        parent = @symbols
          &.find { it.is_a?(Symbol::Union) && it.name == of.to_s }

        union_ref = Symbol.type_ref(module_name, of.to_s)
        parsed_args = args.map { Symbol.parse(it) }

        variant_sym = Symbol::Variant.new(
          module_name:,
          name:        name.to_s,
          args:        parsed_args,
          union:       union_ref,
          decl_span:   nil,
        )

        constructor_sym = Symbol::Constructor.new(
          module_name:,
          name:        name.to_s,
          args:        parsed_args,
          parent:      union_ref,
          decl_span:   nil,
        )

        store(variant_sym)
        store(constructor_sym)

        if parent
          parent
            .with(variants: parent.variants + [variant_sym.to_ref])
            .then { @symbols[@symbols.index(parent)] = it }
        end
      end

      def union(name, *type_params, constructor: false)
        union_symbol = Symbol
          .union(name.to_s, type_params.map { Symbol.var(it, nil) }, [], nil)
          .with(module_name:)
          .tap { store(it) }

        constructor_symbol = if constructor
          Symbol.constructor(
            name.to_s,
            type_params.map { Symbol.var(it, nil) },
            union_symbol,
            nil,
          )
            .with(module_name:)
            .then { store(it) }
        end
      end

      def function(name, params, ret, constraints: [], body: nil, &block)
        qualified_fn_name = "#{module_name}.#{name}"

        codegen = body || "Jade::Runtime.intr('#{qualified_fn_name}')"

        Symbol
          .stdlib_function(
            name.to_s,
            params.transform_values { Symbol.parse(it) },
            Symbol.parse(ret),
            codegen,
            constraints:,
          )
          .with(module_name:)
          .then { store(it) }
          .tap { Runtime.register(qualified_fn_name, &block) }
      end

      def interface(name, type_param, functions, default: {})
        functions
          .map { |k, v| Symbol.parse(v).then { to_interface_function(name, k, it) }.with(module_name:) }
          .then { Symbol.interface(name, Symbol.parse(type_param), it, default, nil) }
          .with(module_name:)
          .then { store(it); it.functions.each { |fn| store(fn) } }
      end

      # Declares that a Jade type is backed by one or more native Ruby classes.
      # This auto-registers runtime dispatch for every implementation declared
      # after this call, so there's no need for manual Runtime.register_impl calls.
      #
      # Future direction: literals should eventually be wrapped in Jade's own
      # Data.define types (e.g. Int[value: 42]) and only unwrapped at interop
      # boundaries. That would make native_type unnecessary — implementation
      # declarations would cover both compile-time and runtime dispatch on their
      # own. It also opens up richer type definitions like:
      #   Int   = InternalInt | Overflow
      #   Float = InternalFloat | NaN | Infinity | NegInfinity
      # See Char for a preview of this direction: it's a distinct type from
      # String even though it's still backed by a Ruby String at runtime.
      def native_type(jade_type_name, *ruby_classes)
        @native_types ||= {}
        @native_types[jade_type_name.to_s] = ruby_classes
      end

      def implementation(interface_name, type, functions)
        interface = imports
          .map(&:symbols)
          .then { [symbols, *it] }
          .flatten
          .find { it.is_a?(Symbol::Interface) && it.name == interface_name }

        interface_ref = interface ? interface.to_ref : interface_to_ref(interface_name)
        default = interface ? interface.default : {}
        type_ref = qualified_type_ref(type)

        Symbol
          .implementation(
            interface_ref,
            type_ref,
            [],
            [],
            functions
              .transform_values { Symbol.value_ref(module_name, it) }
              .merge(default),
            [],
            nil,
          )
          .then { store(it) }

        if (ruby_classes = @native_types&.[](type))
          qualified_iface = "#{interface_to_ref(interface_name).module_name}.#{interface_name}"
          qualified_fns   = functions.transform_values { "#{module_name}.#{it}" }
          ruby_classes.each { Runtime.register_impl(qualified_iface, it, qualified_fns) }
        end
      end

      def qualified_type_ref(type)
        if type.include?('.')
          *mod_parts, name = type.split('.')
          Symbol.type_ref(mod_parts.join('.'), name)

        else
          Symbol.type_ref(module_name, type)
        end
      end

      def symbols
        @symbols || []
      end

      def entry
        @entry || symbols
          .reduce(Registry.entry(module_name)) do |acc, sym|
            acc.define(sym)
          end
          .with(exposes:)
          .then { resolve_imports(it) }
      end

      def import(module_name)
        @imports = imports + [module_name]
      end

      def imports
        @imports || []
      end

      def default_importing(imports)
        @default_imports = if imports == :*
          exposes
        else
          exposes.select { imports.include? it.name }
        end
      end

      def default_imports
        @default_imports || {}
      end

      def default_implementation(params:, body:)
        Symbol::StdlibImplementation[params, body]
      end

      private

      def exposes
        @symbols
          .reject { it.is_a?(Symbol::Implementation) }
          .map { it.to_ref }
      end

      def resolve_imports(entry)
        # TODO: This is the same code from stdlib that auto imports stuff.
        imports
          .reduce(entry) do |acc, stdlib|
            ImportEntry[stdlib.entry.name, stdlib.entry.name, stdlib.default_imports, stdlib.entry.exposes]
              .then { acc.import(it) }
          end
      end

      def store(symbol)
        @symbols ||= []
        @symbols.concat << symbol
      end

      def module_name
        "#{self.name.split('::').last}"
      end

      def load_env(entry, registry)
        Frontend::TypeChecking::Loader
          .load(entry, registry.add_module(entry))
          .then { entry.with(env: it) }
      end

      def interface_to_ref(interface)
        case interface
        in 'Eq' | 'Comparable' | 'Appendable' | 'Mappable' | 'Chainable' | 'Numeric'
          'Basics'

        in 'Decodable'
          'Decode'
        end
          .then { Symbol.type_ref(it, interface.to_s) }
      end

      def to_interface_function(interface_name, fn_name, fn)
        fn => Symbol::FunctionType(params:, return_type:)

        Symbol.interface_function(
          fn_name,
          interface_to_ref(interface_name),
          params,
          return_type,
          nil,
        )
      end
    end
  end
end
