require 'jade/registry'
require 'jade/symbol'
require 'jade/type'

require 'jade/frontend/forward_declaration'
require 'jade/frontend/semantic_analyzer'
require 'jade/frontend/symbol_resolution'
require 'jade/frontend/type_checking'

module Jade
  module Frontend
    extend self

    def run(ast)
      run_up_to_semantic_analysis(ast)
    end

    def run_repl(ast, registry, current_entry, scope)
      registry ||= registry_with_basics
      current_entry ||= entry_with_basics('__Repl__')
      scope ||= SemanticAnalyzer::Scope.new

      ForwardDeclaration
        .declare(ast, current_entry)
        .then do |updated_entry|
          updated_registry = registry.add_module(updated_entry)
          SymbolResolution
            .resolve(ast, updated_registry, updated_entry) 
            .then do |enhanced_ast|
              SemanticAnalyzer.analyze_repl(enhanced_ast, updated_registry)
                .map { |scope| [enhanced_ast, updated_registry, updated_entry, scope] }
            end
        end
    end

    def run_up_to_semantic_analysis(ast)
      registry = registry_with_basics
      current_entry = entry_with_basics('__Test__')

      ForwardDeclaration.declare(ast, current_entry)
        .then { SymbolResolution.resolve(ast, registry.add_module(it), it) }
        .then { SemanticAnalyzer.analyze(it, registry) }
    end

    def entry_with_basics(name)
      Registry.entry('__Test__')
        # Simulate imports
        .add_imported_symbol(Symbol::TypeRef['Basics.Int'])
        .add_imported_symbol(Symbol::TypeRef['Basics.Bool'])
        .add_imported_symbol(Symbol::TypeRef['String.String'])
    end

    def registry_with_basics
      basics_entry = Registry
        .entry('Basics')
        .add_symbol(Symbol.union('Int'))
        .add_symbol(Symbol.union('Bool'))

      strings_entry = Registry
        .entry('String')
        .add_symbol(Symbol.union('String'))

      Registry
        .new
        .add_module(basics_entry)
        .add_module(strings_entry)
    end
  end
end
