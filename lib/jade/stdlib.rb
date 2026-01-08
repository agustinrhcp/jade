require 'jade/stdlib/basics'
require 'jade/stdlib/string'
require 'jade/stdlib/maybe'

module Jade
  module Stdlib
    extend self

    INTRINSICS = %w[Basics String].freeze
    COMPILED = %w[Maybe].freeze

    def load(registry)
      registry
        .then { load_intrinsics(it) }
        .then { load_compiled(it) }
    end

    def apply(registry)
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

    def load_intrinsics(registry)
      registry
        .add_module(Stdlib::Basics.entry)
        .add_module(Stdlib::String.entry)
    end

    def load_compiled(registry)
      [Stdlib::Maybe]
        .reduce(registry) do |acc, stdlib|
          Source[stdlib.uri, stdlib.code]
            .then { ModuleLoader.send(:load_with_forward_declaration_, it, registry) }
        end
    end

    def is_stdlib?(entry)
      is_intrinsic?(entry) || COMPILED.include?(entry.name)
    end
  end
end
