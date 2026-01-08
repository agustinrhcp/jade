require 'fileutils'

require 'jade/parser'
require 'jade/lexer'
require 'jade/ast'
require 'jade/registry'
require 'jade/frontend'
require 'jade/codegen'
require 'jade/module_loader/dependency_resolver'
require 'jade/module_loader/dependency_graph'
require 'jade/module_loader/topological_sort'

require 'jade/stdlib'

module Jade
  module ModuleLoader
    extend self

    def load(source_root, path)
      Source.load(source_root, path)
        .then { load_(it, new_registry(source_root), entry: true) }
        .then { Stdlib.apply(it) }
        .then { compile(it) }
    end

    def load_import(module_name, registry)
      Source
        .load_from_module_name(registry.source_root, module_name)
        .then { load_(it, registry) }
    end

    def emit(registry, path: '.jade/build')
      registry.modules.each do |(_, entry)|
        next if Stdlib.is_intrinsic?(entry)

        full_path = File.join(path, entry.path)
        FileUtils.mkdir_p(File.dirname(full_path))
        File.write(full_path, entry.generated)
      end

      registry
    end

    private

    def compile(registry)
      registry
        .modules_in_topo_order
        .reduce(registry) do |acc, entry|
          Frontend
            .run_entry(entry, acc)
            .map { Codegen.generate_entry(it, acc.add_module(it)) }
            .map { acc.add_module(it) }
            .on_err do
              puts Array(it).map(&:message)
              fail("Compilation error")
            end => Ok(new)
          new
        end
    end

    def load_(source, registry, entry: false)
      source
        .then { Lexer.tokenize(it) }
        .then { Parser.parse(it) } => Ok(ast)

      Registry
        .entry(source.to_module_name)
        .with(ast:)
        .with(source:)
        .with(entry:)
        .then { block_given? ? yield(it) : it }
        .then do |entry|
          registry
            .add_module(entry)
            .then { DependencyResolver.resolve(entry, it) }
        end
    end

    def load_with_forward_declaration_(entry, registry)
      load_(entry, registry) do
        Frontend::ForwardDeclaration.declare_entry(it, registry) => Ok(declared)
        declared
      end
    end

    def new_registry(source_root)
      Registry
        .new
        .with(source_root:)
        .then { Stdlib.load(it) }
    end
  end
end
