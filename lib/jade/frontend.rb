require 'jade/registry'
require 'jade/symbol'
require 'jade/type'

require 'jade/frontend/forward_declaration'
require 'jade/frontend/semantic_analyzer'
require 'jade/frontend/symbol_resolution'
require 'jade/frontend/type_checking'
require 'jade/frontend/fixity_fixer'

module Jade
  module Frontend
    extend self

    def run(ast)
      run_up_to_semantic_analysis(ast)
        .and_then do |(enhanced_ast, registry)|
           TypeChecking
             .check(enhanced_ast, registry)
             .to_result
             .map { [enhanced_ast, registry] }
       end
    end

    def run_repl(ast, registry, current_entry, scope, env, var_gen)
      registry ||= registry_with_basics
      current_entry ||= entry_with_basics('__Repl__')
      scope ||= SemanticAnalyzer::Scope.new
      env ||= TypeChecking::Env.new
      var_gen ||= TypeChecking::VarGen.new

      ForwardDeclaration
        .declare(ast, current_entry)
        .then { |entry| FixityFixer.fix(ast).then { [it, entry] } }
        .then do |fixed_ast, updated_entry|
          updated_registry = registry.add_module(updated_entry)
          SymbolResolution
            .resolve(fixed_ast, updated_registry, updated_entry) 
            .then do |enhanced_ast|
              SemanticAnalyzer
                .analyze_repl(enhanced_ast, updated_registry, scope)
                .and_then do |scope|
                  TypeChecking.check_repl(enhanced_ast, updated_registry, env, var_gen)
                    .map { |type, new_env| [enhanced_ast, type, updated_registry, updated_entry, scope, new_env] }
                end
            end
        end
    end

    def run_up_to_semantic_analysis(ast)
      registry = registry_with_basics
      current_entry = entry_with_basics('__Test__')

      ForwardDeclaration
        .declare(ast, current_entry)
        # TODO: FixityFixer can fail if invalid operators are chained
        .then { |entry| FixityFixer.fix(ast).then { [it, entry] } }
        # TODO: Symbol Resolution can fail if the symbol is not found
        .then { |enh_ast, entry| SymbolResolution.resolve(enh_ast, registry.add_module(entry), entry) }
        .then { SemanticAnalyzer.analyze(it, registry) }
    end

    def entry_with_basics(name)
      Registry.entry('__Test__')
        # Simulate imports
        .add_imported_symbol(Symbol::TypeRef['Basics.Int'])
        .add_imported_symbol(Symbol::TypeRef['Basics.Bool'])
        .add_imported_symbol(Symbol::TypeRef['String.String'])
        .add_imported_symbol(Symbol::ValueRef['Basics.(+)'])
        .add_imported_symbol(Symbol::ValueRef['Basics.(-)'])
        .add_imported_symbol(Symbol::ValueRef['Basics.(*)'])
        .add_imported_symbol(Symbol::ValueRef['Basics.(/)'])
    end

    def registry_with_basics
      strings_entry = Registry
        .entry('String')
        .add_symbol(Symbol.union('String'))

      Registry
        .new
        .add_module(basics_entry)
        .add_module(strings_entry)
    end

    def basics_entry
      Registry
        .entry('Basics')
        .add_symbol(Symbol.union('Int'))
        .add_symbol(Symbol.union('Bool'))
        .add_symbol(
          Symbol.stdlib_function(
            '(+)',
            { a: Symbol::TypeRef['Basics.Int'], b: Symbol::TypeRef['Basics.Int'] },
            Symbol::TypeRef['Basics.Int'],
            ->(a, b) { "#{a} + #{b}" }
          )
        )
        .add_symbol(
          Symbol.stdlib_function(
            '(-)',
            { a: Symbol::TypeRef['Basics.Int'], b: Symbol::TypeRef['Basics.Int'] },
            Symbol::TypeRef['Basics.Int'],
            ->(a, b) { "#{a} - #{b}" }
          )
        )
        .add_symbol(
          Symbol.stdlib_function(
            '(*)',
            { a: Symbol::TypeRef['Basics.Int'], b: Symbol::TypeRef['Basics.Int'] },
            Symbol::TypeRef['Basics.Int'],
            ->(a, b) { "#{a} * #{b}" }
          )
        )
        .add_symbol(
          Symbol.stdlib_function(
            '(/)',
            { a: Symbol::TypeRef['Basics.Int'], b: Symbol::TypeRef['Basics.Int'] },
            Symbol::TypeRef['Basics.Int'],
            ->(a, b) { "#{a} / #{b}" }
          )
        )
    end
  end
end
