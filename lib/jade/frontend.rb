require 'jade/registry'
require 'jade/symbol'
require 'jade/type'
require 'jade/stdlib'

require 'jade/frontend/comment_attacher'
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

    def repl_init
      entry = Registry.entry('JadeRepl')

      Stdlib.load(Registry.new)
        .add_module(entry)
        .then { Stdlib.apply(it) }
        .then do |reg|
          loaded_entry = reg.modules['JadeRepl']
          init_scope = loaded_entry.values
            .reduce(SemanticAnalysis::Scope.new) { |acc, (n, s)| acc.bind(n, s) }
          init_env = TypeChecking::Loader.load(loaded_entry, reg)
          [reg, loaded_entry, init_scope, init_env]
        end
    end

    def repl_stdlib_runtime(registry)
      Stdlib::COMPILED
        .map { registry.get(it) }
        .compact
        .map(&:generated)
        .compact
        .join("; ")
    end

    def run_repl(ast, registry, current_entry, scope, env)
      FixityFixer.fix(ast)
        .then { Desugaring.desugar(it) }
        .then do |fixed_ast|
          ForwardDeclaration
            .declare(fixed_ast, registry, current_entry)
            .and_then do |updated_entry|
              updated_registry = registry.update_module(updated_entry)
              updated_scope = bind_new_values(scope, current_entry, updated_entry)
              updated_env = TypeChecking::Loader.load(updated_entry, updated_registry, env: env)

              SymbolResolution
                .resolve(fixed_ast, updated_registry, updated_entry)
                .and_then do |enhanced_ast|
                  SemanticAnalysis
                    .analyze_repl(enhanced_ast, updated_registry, updated_scope, updated_entry)
                    .and_then do |new_scope|
                      TypeChecking
                        .check_repl(enhanced_ast, updated_registry, updated_env)
                        .map do |(type, new_env)|
                          [enhanced_ast, type, updated_registry, updated_entry, new_scope, new_env]
                        end
                    end
                end
            end
        end
    end

    def bind_new_values(scope, old_entry, new_entry)
      (new_entry.defined_values.keys - old_entry.defined_values.keys)
        .reduce(scope) { |acc, name| acc.bind(name, new_entry.defined_values[name]) }
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
