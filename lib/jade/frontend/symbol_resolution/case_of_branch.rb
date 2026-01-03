module Jade
  module Frontend
    module SymbolResolution
      module CaseOfBranch
        extend self

        def resolve(node, registry, current_entry)
          node => AST::CaseOfBranch(pattern:, body:)

          node
            .with(pattern: SymbolResolution.resolve(pattern, registry, current_entry)) 
            .with(body: SymbolResolution.resolve(body, registry, current_entry)) 
        end
      end
    end
  end
end
