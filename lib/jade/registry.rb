require 'jade/module_loader'
require 'jade/entry'

module Jade
  Registry = Data.define(:modules, :implementations, :source_root, :dependency_graph, :overlays) do
    def initialize(modules: {}, implementations: {}, source_root: nil, dependency_graph: nil, overlays: {})
      super(
        modules:,
        implementations:,
        source_root:,
        dependency_graph: dependency_graph || ModuleLoader::DependencyGraph.new,
        overlays:,
      )
    end

    def self.entry(name)
      Entry.empty(name)
    end

    def modules_in_topo_order
      ModuleLoader::TopologicalSort
        .sort(dependency_graph)
        .map { get(it) }
    end

    def get(module_name)
      modules.dig(module_name)
    end

    def update_module(entry)
      fail 'cannot update entry that does not exist' unless modules[entry.name]

      with(
        modules: modules.merge(entry.name => entry),
        implementations: implementations.merge(entry.implementations),
      )
    end

    def add_module(entry)
      next_registry = with(
        modules: modules.merge(entry.name => entry),
        implementations: implementations.merge(entry.implementations),
      )

      if entry.ast
        ModuleLoader::DependencyResolver.resolve(entry, next_registry)
      else
        next_registry
      end
    end

    def add_dependencies(entry, imports)
      with(dependency_graph: dependency_graph.add(entry.name, imports))
    end

    def find_node_at(uri, offset)
      modules
        .each_value
        .find { it.source&.uri == uri }
        &.ast
        &.find_at(offset)
    end

    def lookup(symbol)
      *module_parts, name = symbol.qualified_name.split('.')
      module_entry = module_parts.join('.').then { modules[it] }

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
