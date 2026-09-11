module Jade
  module Repl
    Imported = Data.define(:as, :all, :cell)

    # What the next cell sees. Every name has exactly one provider, the cell
    # that defined it last or the import that brought it in, so the header
    # generated from a scope imports each module once and no name twice.
    Scope = Data.define(:modules, :values, :types, :instances) do
      def self.empty
        new(modules: {}, values: {}, types: {}, instances: ::Set[])
      end

      def import(node)
        node => AST::ImportDeclaration(module_name:, as:, exposing:)

        case exposing
        in AST::ExposeList(items:) then [items, false]
        in AST::ExposeAll then [[], true]
        in AST::ExposeNone then [[], false]
        end => [items, all]

        items.reduce(add_module(module_name, Imported[as&.as, all, false])) do |scope, item|
          case item
          in AST::ExposeValue(name:) then scope.value(name, module_name)
          in AST::ExposeType(name:) then scope.type(name, module_name, false)
          in AST::ExposeTypeExpand(name:) then scope.type(name, module_name, true)
          end
        end
      end

      def provide(module_name, exposes, instances:)
        exposes
          .reduce(add_module(module_name, Imported[nil, false, true])) do |scope, (kind, name, expand)|
            kind == :type ? scope.type(name, module_name, expand) : scope.value(name, module_name)
          end
          .then { instances ? it.with(instances: it.instances + [module_name]) : it }
      end

      def value(name, module_name)
        with(values: values.merge(name => module_name))
      end

      def type(name, module_name, expand)
        with(types: types.merge(name => [module_name, expand]))
      end

      def header_imports
        modules.filter_map { |name, imported| import_line(name, imported) }
      end

      def names
        values.keys + types.keys
      end

      private

      def add_module(name, imported)
        with(modules: modules.merge(name => imported))
      end

      def import_line(name, imported)
        items = exposed_by(name)
        return nil if imported.cell && items.empty? && !instances.include?(name)

        [
          "import #{name}",
          imported.as&.then { " as #{it}" },
          exposing_clause(imported, items),
        ].join
      end

      def exposing_clause(imported, items)
        return ' exposing (..)' if imported.all
        return '' if items.empty?

        " exposing (#{items.join(', ')})"
      end

      def exposed_by(module_name)
        values
          .select { |_, provider| provider == module_name }
          .keys
          .concat(
            types
              .select { |_, (provider, _)| provider == module_name }
              .map { |name, (_, expand)| expand ? "#{name}(..)" : name },
          )
      end
    end
  end
end
