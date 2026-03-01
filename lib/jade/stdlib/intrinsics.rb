require 'jade/runtime'
require 'jade/symbol'

module Jade
  module Stdlib
    module Intrinsics
      def generate_entry(_)
        entry
      end

      def union(name, *type_params)
        Symbol
          .union(name.to_s, type_params.map { Symbol.var(it, nil) }, [], nil)
          .with(module_name:)
          .then { store(it) }
      end

      def function(name, params, ret, &block)
        qualified_fn_name = "#{module_name}.#{name}"

        Symbol
          .stdlib_function(
            name.to_s,
            params.transform_values { string_to_ref(it) },
            string_to_ref(ret),
            "Jade::Runtime.intr('#{qualified_fn_name}')",
          )
          .with(module_name:)
          .then { store(it )}
          .tap { Runtime.register(qualified_fn_name, &block) }
      end

      def interface(name, type_param, functions)
        functions
          .transform_values do |v|
            
          end
          .then { Symbol.interface(name, type_param, it) }
      end

      def symbols
        @symbols || []
      end

      def entry
        symbols
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

      def string_to_ref(str)
        Symbol.parse(str)
      end

      def module_name
        "#{self.name.split('::').last}"
      end
    end
  end
end
