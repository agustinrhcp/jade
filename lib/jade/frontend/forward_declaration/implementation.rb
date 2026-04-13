module Jade
  module Frontend
    module ForwardDeclaration
      module Implementation
        extend self
        extend Helper

        def shallow(_node, _registry, entry)
          Result[entry, []]
        end

        def deep(node, entry, _registry)
          node => AST::Implementation(interface:, constructor:, functions:)

          interface_ref = entry.lookup_type(interface).to_ref
          type_ref = entry.lookup_type(constructor).to_ref

          fn_map = functions
            .to_h do
              it => AST::ImplementationFunction(name:, fn:)
              [name, Symbol.value_ref(entry.name, fn)]
            end

          Symbol
            .implementation(interface_ref, type_ref, [], [], fn_map, [], node.range)
            .then { entry.define(it) }
            .then { Result[it, []] }
        end
      end
    end
  end
end
