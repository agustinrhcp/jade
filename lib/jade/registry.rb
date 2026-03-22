require 'jade/module_loader'
require 'jade/entry'

module Jade
  class Registry
    attr_reader :dependency_graph, :modules, :source_root, :implementations

    def initialize
      @source_root = nil
      @modules = {}
      # TODO: [ModuleLoaderRefactor] Can leave outside module loader
      @dependency_graph = ModuleLoader::DependencyGraph.new
      @implementations = {}
    end

    def with(**kwargs)
      @source_root = kwargs[:source_root] if kwargs.key?(:source_root)
      self
    end

    def self.entry(name)
      Entry.empty(name)
    end

    def modules_in_topo_order
      # TODO: [ModuleLoaderRefactor] Can leave outside module loader
      ModuleLoader::TopologicalSort
        .sort(@dependency_graph)
        .map { get(it) }
    end

    def get(module_name)
      @modules.dig(module_name)
    end

    def update_module(entry)
      fail 'cannot update entry that does not exist' unless @modules[entry.name]

      entry => Entry(name:)

      @modules = @modules.merge(name => entry)

      self
    end

    def add_module(entry)
      entry => Entry(name:)

      @modules = @modules.merge(name => entry)

      if entry.ast
        # Stdlib intrinsics don't have ast
        ModuleLoader::DependencyResolver.resolve(entry, self)
      end

      @implementations.merge!(entry.implementations)

      self
    end

    def add_dependencies(entry, imports)
      entry => Entry(name:)

      @dependency_graph = dependency_graph.add(name, imports)

      self
    end

    def lookup(symbol)
      *module_parts, name = symbol.qualified_name.split('.')
      module_entry = module_parts.join('.').then { @modules[it] }

      # TODO: [SemanticAnalysis::Exposed]
      case symbol
      in Symbol::ValueRef
        module_entry.values[name]

      in Symbol::TypeRef
        module_entry.types[name]
      end
    end
  end

  ImportEntry = Data.define(:module_name, :alias, :unqualified_symbols, :qualified_symbols)

end
