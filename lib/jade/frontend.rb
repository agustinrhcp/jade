require 'jade/registry'
require 'jade/symbol'
require 'jade/type'
require 'jade/stdlib'

require 'jade/frontend/forward_declaration'
require 'jade/frontend/semantic_analyzer'
require 'jade/frontend/symbol_resolution'
require 'jade/frontend/type_checking'
require 'jade/frontend/fixity_fixer'

module Jade
  module Frontend
    extend self

    def run_entry(initial, registry, basics: true)
      auto_import_stdlib(initial)
        .then { ForwardDeclaration.declare_entry(it, registry) }
        .then { FixityFixer.fix_entry(it) }
        .then { SymbolResolution.resolve_entry(it, registry.add_module(it)) }
        .then { SemanticAnalyzer.analyze_entry(it, registry.add_module(it)) }
        .and_then { TypeChecking.check_entry(it, registry.add_module(it)) }
    end

    def run(ast, basics: true)
      run_up_to_semantic_analysis(ast, basics:)
        .and_then do |(enhanced_ast, registry)|
           TypeChecking
             .check(enhanced_ast, registry)
             .to_result
             .map { [enhanced_ast, registry] }
       end
    end

    def run_repl(ast, registry, current_entry, scope, env, var_gen)
      registry ||= registry_with_basics
      current_entry ||= entry_with_basics('__Repl__', basics: true)
      scope ||= SemanticAnalyzer::Scope.new
      env ||= TypeChecking::Env.new
      var_gen ||= TypeChecking::VarGen.new

      ForwardDeclaration
        .declare(ast, registry, current_entry)
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

    def run_up_to_semantic_analysis(ast, basics: true)
      registry = registry_with_basics
      current_entry =
        case ast
        in AST::Module(name:)
          name
        else
          '__Test__'
        end
          .then { entry_with_basics(it, basics:) }

      ForwardDeclaration
        .declare(ast, registry, current_entry)
        # TODO: [Frontend:HandleErrors]
        .then { |entry| FixityFixer.fix(ast).then { [it, entry] } }
        # TODO: [Frontend:HandleErrors]
        .then { |enh_ast, entry| SymbolResolution.resolve(enh_ast, registry.add_module(entry), entry) }
        .then { SemanticAnalyzer.analyze(it, registry) }
    end

    def entry_with_basics(name, basics:)
      entry = Registry.entry(name)
      return entry unless basics

      auto_import_stdlib(entry)
    end

    def auto_import_stdlib(entry)
      [Stdlib::Basics.exposed.values, Stdlib::String.exposed.values]
        .flatten
        .reduce(entry) do |acc, sym|
          acc.add_imported_symbol(sym)
        end
        .add_import(Stdlib::Basics.entry)
        .add_import(Stdlib::String.entry)
    end

    def registry_with_basics
      Registry
        .new
        .add_module(Stdlib::Basics.entry)
        .add_module(Stdlib::String.entry)
    end
  end
end
