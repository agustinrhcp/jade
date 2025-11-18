module Jade
  class Registry
    def initialize
      @modules = {}
    end

    def self.entry(name)
      ModuleEntry.new(name:, values: {}, types: {}, imports: Set[], exports: [])
    end

    def add_module(entry)
      entry => ModuleEntry(name:)

      @modules = @modules.merge(name => entry)
      self
    end

    def lookup(symbol)
      *module_parts, name = symbol.qualified_name.split('.')
      module_entry = module_parts.join('.').then { @modules[it] }

      case symbol
      in Symbol::ValueRef
        module_entry.values[name]

      in Symbol::TypeRef
        module_entry.types[name]
      end
    end
  end

  ImportEntry = Data.define(:module_name, :alias, :symbols)

  ModuleEntry = Data.define(:name, :values, :types, :imports, :exports) do
    def add_symbol(symbol)
      case symbol
      in Symbol::Union
        add_local_type_symbol(symbol)

      in Symbol::Function | Symbol::StdlibFunction
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

    def lookup_value(name)
      values[name] || find_import(name)
    end

    def lookup_type(name)
      types[name]
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
      symbol.with(module_name: name)
        .then { with(types: types.merge(it.name => it)) }
    end
  end
end
