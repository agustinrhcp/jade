require 'jade/module_loader'

module Jade
  class Registry
    attr_reader :dependency_graph, :modules, :source_root

    def initialize
      @source_root = nil
      @modules = {}
      # TODO: [ModuleLoaderRefactor] Can leave outside module loader
      @dependency_graph = ModuleLoader::DependencyGraph.new
    end

    def with(**kwargs)
      @source_root = kwargs[:source_root] if kwargs.key?(:source_root)
      self
    end

    def self.entry(name)
      ModuleEntry.new(
        name:,
        values: {},
        types: {},
        imports: Set[],
        exposes: {},
        ast: nil,
        source: nil,
        generated: nil,
        entry: false,
      )
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

      entry => ModuleEntry(name:)

      @modules = @modules.merge(name => entry)

      self
    end

    def add_module(entry)
      entry => ModuleEntry(name:)

      @modules = @modules.merge(name => entry)

      if entry.ast
        # Stdlib intrinsics don't have ast
        ModuleLoader::DependencyResolver.resolve(entry, self)
      end

      self
    end

    def add_dependencies(entry, imports)
      entry => ModuleEntry(name:)

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

  ImportEntry = Data.define(:module_name, :alias, :symbols)

  ModuleEntry = Data.define(:name, :values, :types, :imports, :exposes, :ast, :source, :generated, :entry) do
    def add_expose(qualified_name, symbol)
      with(exposes: exposes.merge(qualified_name => symbol))
    end

    def add_symbol(symbol)
      case symbol
      in Symbol::Union
        add_local_type_symbol(symbol)

      in Symbol::Function | Symbol::StdlibFunction | Symbol::Variant
        add_local_value_symbol(symbol)
      end
    end

    def add_imported_symbol(symbol)
      case symbol
      in Symbol::TypeRef
        with(types: types.merge(Symbol.unqualified_name(symbol.qualified_name) => symbol))

      in Symbol::ValueRef
        with(values: values.merge(Symbol.unqualified_name(symbol.qualified_name) => symbol))
      end
    end

    def add_import(entry, as: entry.name)
      ImportEntry[entry.name, as, []]
        .then { with(imports: imports + [it]) }
    end

    def lookup_value(name)
      values[name] || find_import(name)
    end

    def lookup_type(name)
      types[name]
    end

    def path
      source.uri.gsub('.jd', '.rb')
    end

    private

    def find_import(name)
      *module_name_parts, unqualified_name = name.split('.')
      module_name = module_name_parts.join('.')

      imports
        .find { |import| import.alias == module_name }
        &.[](unqualified_name)
    end

    def add_local_value_symbol(symbol)
      symbol
        .with(module_name: name)
        .then { with(values: values.merge(it.name => it)) }
    end

    def add_local_type_symbol(symbol)
      symbol
        .with(
          module_name: name,
          variants: symbol.variants.map { it.with(module_name: name) },
        )
        .then { with(types: types.merge(it.name => it)) }
    end
  end
end
