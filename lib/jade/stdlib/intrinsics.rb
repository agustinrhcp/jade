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
          .union(name.to_s, type_params.map { Symbol.var(it) }, [])
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
        case str
        in 'Int' then Symbol::TypeRef['Basics', 'Int']
        in 'Float' then Symbol::TypeRef['Basics', 'Float']
        in 'Bool' then Symbol::TypeRef['Basics', 'Bool']
        in 'String' then Symbol::TypeRef['String', 'String']

      # TODO: don't hardcode thaaat much
        in 'a' then Symbol.var('a')
        in 'b' then Symbol.var('b')
        in 'a -> b' then Symbol.function_type([Symbol.var('a')], Symbol.var('b'))
        in 'Maybe(Int)' then Symbol.type_ref('Maybe', 'Maybe')
        in 'List(a)' then Symbol.type_ref('List', 'List') 
        in 'List(b)' then Symbol.type_ref('List', 'List') 
        in 'List(String)' then Symbol.type_ref('List', 'List') 
        in 'Int, a -> b' then Symbol.function_type([string_to_ref('Int'), string_to_ref('a')], string_to_ref('b'))
        in 'b, a -> b' then Symbol.function_type([string_to_ref('b'), string_to_ref('a')], string_to_ref('b'))
        end
      end

      def module_name
        "#{self.name.split('::').last}"
      end
    end
  end
end
