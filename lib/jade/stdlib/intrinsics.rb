require 'jade/runtime'
require 'jade/symbol'

module Jade
  module Stdlib
    module Intrinsics
      def union(name)
        Symbol
          .union(name.to_s, [], [])
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
            acc.add_symbol(sym)
          end
          .with(exposes: exposed)
      end

      def exposing(val)
        @exposes = val
      end

      def exposed
        case @exposes
        in :*
          @symbols.map { [it.name, it.to_ref] }.to_h
        end
      end

      private

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
        end
      end

      def module_name
        "#{self.name.split('::').last}"
      end
    end
  end
end
