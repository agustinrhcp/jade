require 'jade/stdlib/basics'
require 'jade/stdlib/maybe'
require 'jade/stdlib/list'
require 'jade/stdlib/char'
require 'jade/stdlib/tuple'
require 'jade/stdlib/string'
require 'jade/stdlib/result'
require 'jade/stdlib/task'

module Jade
  module Stdlib
    extend self

    INTRINSICS = %w[Basics String List Tuple Char Task].freeze
    COMPILED = %w[Maybe Result].freeze
    STDLIBS = [Stdlib::Basics, Stdlib::Maybe, Stdlib::List, Stdlib::Char, Stdlib::Tuple, Stdlib::String, Stdlib::Result, Stdlib::Task]

    def load(registry)
      registry
        .then { load_stdlib(registry) }
    end

    def apply(registry)
      # TODO: [ModuleLoaderRefactor] This should live in registry probably
      user_entries = registry
        .modules
        .values
        .reject { is_stdlib?(it) }

      user_entries
        .reduce(registry) do |acc, entry|
          add_imports(entry)
            .then { acc.add_module(it) }
        end
    end

    def requires(name)
      return "" if COMPILED.include?(name)

      prefix = '../' * name.count('.')
      COMPILED
        .map(&:downcase)
        .map { "require_relative '#{prefix}#{it}'; "}
        .join("")
    end

    PRIVATE_CONSTRUCTORS = %w[Tuple.Tuple2 Tuple.Tuple3 Tuple.Tuple4].freeze

    def is_intrinsic?(entry)
      INTRINSICS.include? entry.name
    end

    def private_constructor?(name)
      PRIVATE_CONSTRUCTORS.include?(name)
    end

    private

    def add_imports(entry)
      STDLIBS
        .reduce(entry) do |acc, stdlib|
          ImportEntry[stdlib.entry.name, stdlib.entry.name, stdlib.default_imports, stdlib.entry.exposes]
            .then { acc.import(it) }
        end
    end

    def load_stdlib(registry)
      STDLIBS
        .reduce(registry) do |acc, stdlib|
          stdlib.generate_entry(acc)
          registry.add_module(stdlib.entry)
        end
    end

    def is_stdlib?(entry)
      is_intrinsic?(entry) || COMPILED.include?(entry.name)
    end
  end
end
