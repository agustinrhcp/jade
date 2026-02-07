module Jade
  Entry = Data.define(:name, :defined_values, :defined_types, :imports, :exposes, :ast, :source, :generated, :entry) do
    def expose(symbol)
      with(exposes: exposes + Set[symbol])
    end

    def import(import_entry)
      with(imports: imports + Set[import_entry])
    end

    def exposed_value(unqualified_name)
      exposes
        .find { it.is_a?(Symbol::ValueRef) && it.name == unqualified_name }
    end

    def exposed_type(unqualified_name)
      exposes
        .find { it.is_a?(Symbol::TypeRef) && it.name == unqualified_name }
    end

    def exposed_type_variants(unqualified_name)
      type_ref = exposes
        .find { it.is_a?(Symbol::TypeRef) && it.name == unqualified_name }

      return nil unless type_ref

      (types[unqualified_name].variants & exposes.to_a)
        .then { it.empty? ? nil : it }
    end

    def imported_values
      imports
        .flat_map(&:unqualified_symbols)
        .select { it.is_a?(Symbol::ValueRef) }
        .map { [it.name, it] }
        .to_h
    end

    def imported_types
      imports
        .flat_map(&:unqualified_symbols)
        .select { it.is_a?(Symbol::TypeRef) }
        .map { [it.name, it] }
        .to_h
    end

    def values
      imported_values.merge(defined_values)
    end

    def types
      imported_types.merge(defined_types)
    end

    def define(symbol)
      case symbol
      in Symbol::Union | Symbol::Struct
        add_defined_type(symbol)

      in Symbol::Function | Symbol::StdlibFunction | Symbol::Variant | Symbol::InteropFunction
        add_defined_value(symbol)
      end
    end

    def lookup_value(name)
      values[name]
    end

    def lookup_type(name)
      types[name]
    end

    def lookup_qualified_type(as, type_name)
      imports
        .find { it.alias == as }
        &.qualified_symbols&.find { it.is_a?(Symbol::TypeRef) && it.name == type_name }
    end

    def path
      source.uri.gsub('.jd', '.rb')
    end

    private

    def add_defined_value(symbol)
      symbol
        .with(module_name: name)
        .then { with(defined_values: defined_values.merge(it.name => it)) }
    end

    def add_defined_type(symbol)
      case symbol
      in Symbol::Union
        symbol
          .with(
            module_name: name,
            variants: symbol.variants.map { it.with(module_name: name) },
          )
      else
        symbol.with(module_name: name)
      end
        .then { with(defined_types: defined_types.merge(it.name => it)) }
    end
  end
end
