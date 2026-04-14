require 'jade/registry'
require 'jade/symbol'
require 'jade/type'
require 'jade/stdlib'

require 'jade/frontend/forward_declaration'
require 'jade/frontend/semantic_analysis'
require 'jade/frontend/symbol_resolution'
require 'jade/frontend/type_checking'
require 'jade/frontend/fixity_fixer'
require 'jade/frontend/desugaring'

module Jade
  module Frontend
    extend self

    def run_entry(initial, registry)
      initial
        .then { FixityFixer.fix_entry(it) }
        .then { Desugaring.desugar_entry(it) }
        .then { ForwardDeclaration.declare_entry(it, registry) }
        .and_then { SymbolResolution.resolve_entry(it, registry.update_module(it)) }
        .and_then { SemanticAnalysis.analyze(it, registry.update_module(it)) }
        .and_then { TypeChecking.check(it, registry.update_module(it)) }
    end

    def run(ast)
      run_up_to_semantic_analysis(ast)
        .and_then do |(entry, registry)|
          TypeChecking
            .check(entry, registry)
            .map { [entry.ast, registry] }
       end
    end

    def run_repl(ast, registry, current_entry, scope, env, var_gen)
      registry ||= registry_with_basics
      current_entry ||= entry_with_basics('JadeRepl')
      scope ||= SemanticAnalysis::Scope.new
      env ||= TypeChecking::Env.new
      var_gen ||= TypeChecking::VarGen.new

      ForwardDeclaration
        .declare(ast, registry, current_entry)
        .then { |entry| FixityFixer.fix(ast).then { [it, entry] } }
        .then do |fixed_ast, updated_entry|
          updated_registry = registry.update_module(updated_entry)
          SymbolResolution
            .resolve(fixed_ast, updated_registry, updated_entry) 
            .then do |enhanced_ast|
              SemanticAnalysis
                .analyze_repl(enhanced_ast, updated_registry, scope)
                .and_then do |scope|
                  TypeChecking.check_repl(enhanced_ast, updated_registry, env, var_gen)
                    .map { |type, new_env| [enhanced_ast, type, updated_registry, updated_entry, scope, new_env] }
                end
            end
        end
    end

    def run_up_to_semantic_analysis(ast)
      registry, current_entry = entry_with_basics(ast)

      FixityFixer.fix(ast)
        .then { Desugaring.desugar(it) }
        .then { |enh_ast| ForwardDeclaration.declare(enh_ast, registry, current_entry).map { [enh_ast, it] } }
        .and_then do |enh_ast, entry|
          SymbolResolution
            .resolve(enh_ast, registry.update_module(entry), entry)
            .map { entry.with(ast: it) }
        end
        .and_then { |entry| SemanticAnalysis.analyze(entry, registry.update_module(entry)) }
        .map { [it, registry.update_module(it)] }
    end

    def entry_with_basics(ast)
      entry =
        case ast
        in AST::Module(name:)
          name
        else
          '__Test__'
        end
          .then { Registry.entry(it).with(ast:) }

      Stdlib.load(Registry.new)
        .add_module(entry)
        .then { Stdlib.apply(it) }
        .then { [it, it.modules[entry.name]] }
    end
  end
end
