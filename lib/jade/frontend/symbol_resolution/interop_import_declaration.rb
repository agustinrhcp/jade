module Jade
  module Frontend
    module SymbolResolution
      module InteropImportDeclaration
        extend self

        def resolve(node, registry, current_entry)
          node => AST::InteropImportDeclaration(functions:)

          functions
            .map do |fn|
              current_entry.lookup_value(fn.name)
                .then { fn.with(symbol: it) }
            end
            .then { node.with(functions: it) }
            .then { Result[it, []] }
        end
      end
    end
  end
end
