require 'jade/registry'
require 'jade/symbol'
require 'jade/frontend/symbol_resolution'

module Jade
  module Frontend
    extend self

    def run(ast)
      basics_entry = Registry
        .entry('Basics')
        .add_symbol(Symbol.union('Int'))
        .add_symbol(Symbol.union('Bool'))

      strings_entry = Registry
        .entry('String')
        .add_symbol(Symbol.union('String'))

      registry = Registry
        .new
        .add_module(basics_entry)
        .add_module(strings_entry)

      SymbolResolution
        .resolve(ast, registry)
    end
  end
end
