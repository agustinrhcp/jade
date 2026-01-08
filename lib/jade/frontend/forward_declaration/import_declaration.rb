module Jade
  module Frontend
    module ForwardDeclaration
      module ImportDeclaration
        extend self

        # TODO: This does a lot, so It could just be import registration.
        #  everything else doesn't need the registry at all
        def shallow(ast, registry, entry)
          ast => AST::ImportDeclaration(module_name:)
          imported_entry = registry.get(module_name) => { types:, values: }

          # TODO: add module to imports
          # only do this if import (..)
          (types.values + values.values)
            .map(&:to_ref)
            .reduce(entry.add_import(imported_entry)) do |acc, sym|
              acc.add_imported_symbol(sym)
            end
            .then { Result[it, []] }
        end

        def deep(_, entry)
          Result[entry, []]
        end
      end
    end
  end
end
