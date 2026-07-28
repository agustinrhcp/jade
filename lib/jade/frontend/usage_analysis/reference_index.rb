module Jade
  module Frontend
    module UsageAnalysis
      # `owner` is the key of the enclosing declaration or implementation,
      # `nil` only at module level. Declaration owners share the
      # `symbol_key` namespace, so a reference's owner can be looked up in
      # the index that produced it.
      Reference = Data.define(:symbol_key, :kind, :range, :owner)

      ReferenceIndex = Data.define(:references) do
        def initialize(references: {})
          super
        end

        def self.empty
          new(references: {})
        end

        def for(symbol)
          references[ReferenceIndex.key_for(symbol)] || []
        end

        def passed_as_value?(symbol)
          self.for(symbol).any? { it.kind == :as_value }
        end

        def ever_referenced?(symbol)
          self.for(symbol).any?
        end

        def references_in(module_name)
          references
            .values
            .flatten
            .select { it.symbol_key.first == module_name }
        end

        # Locals key on `decl_span`; module-level symbols on
        # `[module_name, name]`. NOTE: when `:type_annotation` refs land
        # they may point at a `Symbol::Variable` that's a *type*
        # variable, which would collide with value-level locals under
        # `[:local, decl_span]`. Revisit the keying scheme then —
        # likely split into `[:local_value, ...]` vs `[:local_type, ...]`.
        def self.key_for(symbol)
          case symbol
          in Symbol::Variable
            [:local, symbol.decl_span]
          in Symbol::Implementation
            [:impl, symbol.interface.qname, symbol.type.qname]
          in Symbol::ValueRef | Symbol::TypeRef
            [symbol.module_name, symbol.name]
          else
            [symbol.module_name, symbol.name]
          end
        end
      end
    end
  end
end
