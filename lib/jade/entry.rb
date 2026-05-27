module Jade
  Entry = Data.define(
    :name,
    :defined_values,
    :defined_types,
    :imports,
    :exposes,
    :ast,
    :source,
    :env,
    :generated,
    :implementations,
    :entry,
    :diagnostics,
    :usage_index,
  ) do

    def self.empty(name)
      new(
        name:,
        defined_values: {},
        defined_types: {},
        imports: ::Set[],
        exposes: ::Set[],
        ast: nil,
        source: nil,
        generated: nil,
        env: nil,
        implementations: {},
        entry: false,
        diagnostics: Diagnostics::List.empty,
        usage_index: nil,
      )
    end

    def expose(symbol)
      with(exposes: exposes + ::Set[symbol])
    end

    def import(import_entry)
      with(imports: imports + ::Set[import_entry])
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

      types[unqualified_name]
        .constructor_refs
        .then { it & exposes.to_a }
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
      in Symbol::Union | Symbol::Struct | Symbol::Interface
        add_defined_type(symbol)

      in Symbol::Implementation
        add_implementation(symbol)

      in Symbol::Function | Symbol::StdlibFunction |
        Symbol::Constructor | Symbol::Variant |
        Symbol::InteropFunction | Symbol::InterfaceFunction
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

    # Source spans are stripped so unrelated edits (e.g. whitespace) shifting
    # one definition's span don't bust caches for consumers of others.
    def interface_digest
      Digest::SHA256.hexdigest(Marshal.dump(interface_snapshot))
    end

    private

    def interface_snapshot
      value_names = exposes.filter_map { it.is_a?(Symbol::ValueRef) ? it.name : nil }.sort
      type_names  = exposes.filter_map { it.is_a?(Symbol::TypeRef)  ? it.name : nil }.sort

      [
        value_names,
        type_names,
        value_names.map { ModuleLoader::Normalize.apply(defined_values[it]) },
        type_names .map { ModuleLoader::Normalize.apply(defined_types[it])  },
        implementations.keys.sort.map { [it, ModuleLoader::Normalize.apply(implementations[it])] },
      ]
    end

    def add_implementation(symbol)
      symbol
        .with(module_name: name)
        .then { implementations.merge([it.interface.qualified_name, it.type.qualified_name] => it) }
        .then { with(implementations: it) }
    end

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

      in Symbol::Interface(functions:)
        symbol
          .with(module_name: name)
          .with(functions: functions.map { it.with(module_name: name) })

      else
        symbol.with(module_name: name)
      end
        .then { with(defined_types: defined_types.merge(it.name => it)) }
    end
  end
end
