module Jade
  module Frontend
    module SymbolResolution
      module FunctionCall
        extend self

        def resolve(node, registry, current_entry)
          node => AST::FunctionCall(callee:, args:)

          node
            .with(callee: SymbolResolution.resolve(callee, registry, current_entry))
            .with(args: args.map { SymbolResolution.resolve(it, registry, current_entry) })
        end
      end
    end
  end
end
