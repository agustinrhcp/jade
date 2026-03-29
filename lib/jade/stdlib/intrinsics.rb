require 'jade/runtime'
require 'jade/symbol'

require 'jade/frontend/type_checking/loader'

module Jade
  module Stdlib
    module Intrinsics
      def generate_entry(registry)
        @entry = entry
          .then { load_env(it, registry) }
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

      def function(name, params, ret, &block)
        qualified_fn_name = "#{module_name}.#{name}"

        Symbol
          .stdlib_function(
            name.to_s,
            params.transform_values { Symbol.parse(it) },
            Symbol.parse(ret),
            "Jade::Runtime.intr('#{qualified_fn_name}')",
          )
          .with(module_name:)
          .then { store(it )}
          .tap { Runtime.register(qualified_fn_name, &block) }
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

      private

      def exposes
        @symbols.map { it.to_ref }
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
    end
  end
end
