require 'jade/stdlib/basics'
require 'jade/stdlib/maybe'
require 'jade/stdlib/string'
require 'jade/stdlib/result'

module Jade
  module Stdlib
    extend self

    INTRINSICS = %w[Basics String].freeze
    COMPILED = %w[Maybe Result].freeze

    def load(registry)
      registry
        .then { load_stdlib(registry) }
    end

    def apply(registry)
      # TODO: [ModuleLoaderRefactor] This should live in registry probably
      stdlib_entries, user_entries = registry
        .modules
        .values
        .partition { is_stdlib?(it) }

      user_entries
        .reduce(registry) do |acc, entry|
          add_imports(entry, stdlib_entries)
            .then { acc.add_module(it) }
        end
    end

    def requires(name)
      return "" if COMPILED.include?(name)

      COMPILED
        .map(&:downcase)
        .map { "require_relative '#{it}'; "}
        .join("")
    end

    def is_intrinsic?(entry)
      INTRINSICS.include? entry.name
    end

    private

    def add_imports(entry, stdlib_entries)
      # TODO: [ModuleLoaderRefactor] This should live in registry probably
      # TODO: This is copy pasted from somewhere else
      stdlib_entries
        .reduce(entry) do |acc, stdlib|
          stdlib
            .exposes
            .values
            .reduce(acc) do |acc2, sym|
              acc2.add_imported_symbol(sym)
            end
            .add_import(stdlib)
        end
    end

    def load_stdlib(registry)
      [Stdlib::Basics, Stdlib::Maybe, Stdlib::String, Stdlib::Result]
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
