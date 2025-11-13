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

      current_entry = ForwardDeclaration
        .declare(ast, Registry.entry('__Test__'))

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
