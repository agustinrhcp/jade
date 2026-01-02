module Jade
  module Frontend
    module SymbolResolution
      module Module
        extend self

        def resolve(node, registry, current_entry)
          node => AST::Module(body:)

          SymbolResolution
            .resolve(body, registry, current_entry)
            .then { node.with(body: it) }
        end
      end
    end
  end
end
