module Jade
  module Codegen
    module Pattern
      module Constructor
        extend self
        extend Helpers

        def generate(node, registry)
          node => AST::Pattern::Constructor(symbol:, patterns:)
          constructor = registry.lookup(symbol)
          qualified = to_qualified(constructor.qualified_name)

          if keyed_variant?(constructor)
            generate_keyed(qualified, patterns.first, registry)
          else
            generate_positional(qualified, patterns, registry)
          end
        end

        private

        def keyed_variant?(constructor)
          constructor.args in [Symbol::RecordType]
        end

        def generate_positional(qualified, patterns, registry)
          patterns
            .map { generate_node(it, registry) }
            .join(', ')
            .then { it.empty? ? it : "(#{it})" }
            .then { "#{qualified}#{it}" }
        end

        # Keyed variants have a single inner pattern that conceptually matches
        # the record-shaped payload. The runtime class itself carries the
        # record's fields, so we project the pattern onto the variant directly:
        # binding/wildcard captures the whole instance; record patterns
        # destructure via Ruby's Data deconstruct_keys.
        def generate_keyed(qualified, pattern, registry)
          case pattern
          in AST::Pattern::Binding(name:)
            "#{qualified} => #{name}"

          in AST::Pattern::Wildcard
            qualified

          in AST::Pattern::Record(fields:)
            fields
              .map { generate_node(it, registry) }
              .join(', ')
              .then { "#{qualified}(#{it})" }
          end
        end
      end
    end
  end
end
