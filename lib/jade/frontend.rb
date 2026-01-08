require 'jade/registry'
require 'jade/symbol'
require 'jade/type'
require 'jade/stdlib'

require 'jade/frontend/forward_declaration'
require 'jade/frontend/semantic_analyzer'
require 'jade/frontend/symbol_resolution'
require 'jade/frontend/type_checking'
require 'jade/frontend/fixity_fixer'
require 'jade/frontend/desugaring'

module Jade
  module Frontend
    extend self

    def run_entry(initial, registry, basics: true)
      auto_import_stdlib(initial)
        .then { ForwardDeclaration.declare_entry(it, registry) }
        .map { FixityFixer.fix_entry(it) }
        .map { Desugaring.desugar_entry(it) }
        .and_then { SymbolResolution.resolve_entry(it, registry.add_module(it)) }
        .and_then { SemanticAnalyzer.analyze(it, registry.add_module(it)) }
        .and_then { TypeChecking.check(it, registry.add_module(it)) }
    end

    def run(ast, basics: true)
      run_up_to_semantic_analysis(ast, basics:)
        .and_then do |(entry, registry)|
          TypeChecking
            .check(entry, registry)
            .map { [entry.ast, registry] }
       end
    end

    def run_repl(ast, registry, current_entry, scope, env, var_gen)
      registry ||= registry_with_basics
      current_entry ||= entry_with_basics('JadeRepl', basics: true)
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
        .map { |entry| FixityFixer.fix(ast).then { [it, entry] } }
        .map { |enh_ast, entry| Desugaring.desugar(enh_ast).then { [it, entry] } }
        .and_then do |enh_ast, entry|
          SymbolResolution
            .resolve(enh_ast, registry.add_module(entry), entry)
            .map { entry.with(ast: it) }
        end
        .and_then { |entry| SemanticAnalyzer.analyze(entry, registry.add_module(entry)) }
        .map { [it, registry.add_module(it)] }
    end

    def entry_with_basics(name, basics:)
      entry = Registry.entry(name)
      return entry unless basics

      auto_import_stdlib(entry)
    end

    def auto_import_stdlib(entry)
      # TODO: Improve this when working on imports.
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
