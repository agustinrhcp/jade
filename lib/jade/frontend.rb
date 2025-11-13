require 'jade/registry'
require 'jade/symbol'

require 'jade/frontend/forward_declaration'
require 'jade/frontend/semantic_analyzer'
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

      current_entry = Registry.entry('__Test__')
        # Simulate imports
        .add_imported_symbol(basics_entry.lookup_type('Int').to_ref)
        .add_imported_symbol(basics_entry.lookup_type('Bool').to_ref)
        .add_imported_symbol(strings_entry.lookup_type('String').to_ref)
        .then { ForwardDeclaration.declare(ast, it) }

      registry = Registry
        .new
        .add_module(basics_entry)
        .add_module(strings_entry)
        .add_module(current_entry)

      SymbolResolution
        .resolve(ast, registry, current_entry)
        .then { |it| SemanticAnalyzer.analyze(it, registry) }
    end
  end
end
