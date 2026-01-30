module Jade
  module Frontend
    module ForwardDeclaration
      module Module
        extend self
        extend Helper

        def shallow(node, registry, entry)
          node => AST::Module(body:)

          shallow_declare_node(body, registry, entry)
        end

        def deep(node, entry, registry)
          node => AST::Module(exposing:, body:)

          case exposing
          in AST::ExposeList(items:)
            items
              .reduce(Result[entry, []]) do |acc, exposed|
                case exposed
                in AST::ExposeValue(name:, range:)
                  lookup_and_expose_value(acc.entry, name, range)

                in AST::ExposeType(name:, range:)
                  lookup_and_expose_type(acc.entry, name, range)

                in AST::ExposeTypeExpand(name:, range:)
                  lookup_and_expose_type_with_variants(acc.entry, name, range)
                end
                  .add_errors(acc.errors)
              end

          in AST::ExposeAll
            entry
              .values
              .merge(entry.types)
              .reduce(entry) { |acc, (name, sym)| acc.expose(sym) }
              .then { Result[it, []] }

          in AST::ExposeNone
            Result[entry, []]
          end
            .then { deep_declare_node(body, it.entry, registry).add_errors(it.errors) }
        end

        private

        def lookup_and_expose_type(entry, name, span)
          symbol = entry.lookup_type(name)

          if symbol
            return entry
              .expose(symbol.to_ref)
              .then { Result[it, []] }
          end

          Result[
            entry,
            [Error::ExposedTypeNotFound.new(entry.name, span, name:)],
          ]
        end

        def lookup_and_expose_type_with_variants(entry, name, span)
          symbol = entry.lookup_type(name)

          if symbol
            return symbol
              .variants
              .reduce(entry) { |acc, variant| acc.expose(variant.to_ref) }
              .expose(symbol.to_ref)
              .then { Result[it, []] }
          end

          Result[
            entry,
            [Error::ExposedTypeNotFound.new(entry.name, span, name:)],
          ]
        end

        def lookup_and_expose_value(entry, name, span)
          symbol = entry.lookup_value(name)

          if symbol
            return entry
              .expose(symbol.to_ref)
              .then { Result[it, []] }
          end

          Result[
            entry,
            [Error::ExposedValueNotFound.new(entry.name, span, name:)],
          ]
        end
      end
    end
  end
end
