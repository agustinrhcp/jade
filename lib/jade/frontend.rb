require 'jade/registry'
require 'jade/symbol'
require 'jade/type'
require 'jade/stdlib'

require 'jade/frontend/comment_attacher'
require 'jade/frontend/forward_declaration'
require 'jade/frontend/semantic_analysis'
require 'jade/frontend/usage_analysis'
require 'jade/frontend/type_checking'
require 'jade/frontend/fixity_fixer'
require 'jade/frontend/desugaring'
require 'jade/frontend/desugaring/resolved'

module Jade
  module Frontend
    extend self

    def run_entry(initial, registry)
      initial
        .then { FixityFixer.fix_entry(it) }
        .then { Desugaring.desugar_entry(it) }
        .then { ForwardDeclaration.declare_entry(it, registry) }
        .and_then { SemanticAnalysis.analyze(it, registry.update_module(it)) }
        .map { Desugaring.desugar_resolved_entry(it, registry.update_module(it)) }
        .map { UsageAnalysis.analyze(it, registry.update_module(it)) }
        .and_then { TypeChecking.check(it, registry.update_module(it)) }
    end

    def run(ast)
      run_up_to_semantic_analysis(ast)
        .and_then do |(entry, registry)|
          TypeChecking
            .check(entry, registry)
            .map { [it.ast, registry.update_module(it)] }
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
          SemanticAnalysis
            .analyze_repl(fixed_ast, updated_registry, scope, updated_entry)
            .and_then do |(enhanced_ast, new_scope)|
              enhanced_ast = Desugaring.desugar_resolved(enhanced_ast, updated_registry)
              TypeChecking.check_repl(enhanced_ast, updated_registry, env, var_gen)
                .map { |type, new_env| [enhanced_ast, type, updated_registry, updated_entry, new_scope, new_env] }
            end
        end
    end

    def run_up_to_semantic_analysis(ast)
      registry, current_entry = entry_with_basics(ast)

      FixityFixer.fix(ast)
        .then { Desugaring.desugar(it) }
        .then { |enh_ast| ForwardDeclaration.declare(enh_ast, registry, current_entry).map { [enh_ast, it] } }
        .and_then do |enh_ast, entry|
          SemanticAnalysis.analyze(entry.with(ast: enh_ast), registry.update_module(entry))
        end
        .map { Desugaring.desugar_resolved_entry(it, registry.update_module(it)) }
        .map { UsageAnalysis.analyze(it, registry.update_module(it)) }
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
