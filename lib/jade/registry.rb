module Jade
  class Registry
    def initialize
      @modules = {}
    end

    def self.entry(name)
      ModuleEntry.new(name:, values: {}, types: {}, imports: [], exports: [])
    end

    def add_module(entry)
      entry => ModuleEntry(name:)

      @modules = @modules.merge(name => entry)
      self
    end
  end

  ModuleEntry = Data.define(:name, :values, :types, :imports, :exports) do
    def add_symbol(symbol)
      case symbol
      in Symbol::Type
        add_type_symbol(symbol)
      end
    end

    private

    def add_value_symbol(symbol)
      symbol
        .with(module_name: name)
        .then { with(values: values.merge(it.name => it)) }
    end

    def add_type_symbol(symbol)
      symbol.with(module_name: name)
        .then { with(types: types.merge(it.name => it)) }
    end
  end
end
