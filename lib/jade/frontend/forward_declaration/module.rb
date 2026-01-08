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

        def deep(node, entry)
          node => AST::Module(exposing:, body:)

          case exposing
          in AST::ExposeList(items:)
            items
              .reduce(Result[entry, []]) do |acc, exposed|
                case exposed
                in AST::VariableReference(name:, range:)
                  lookup_and_expose_value(acc.entry, name, range)

                in AST::TypeName(type:, range:)
                  lookup_and_expose_type(acc.entry, type, range)
                end
                  .add_errors(acc.errors)
              end

          in AST::ExposeAll
            entry
              .values
              .merge(entry.types)
              .reduce(entry) do |acc, (name, sym)|
                acc.add_expose(name, sym)
              end
              .then { Result[it, []] }

          in AST::ExposeNone
            Result[entry, []]
          end
            .then { deep_declare_node(body, it.entry).add_errors(it.errors) }
        end

        private

        def lookup_and_expose_type(entry, name, span)
          symbol = entry.lookup_type(name)

          if symbol
            return symbol
              .variants
              .reduce(entry) do |acc, variant|
                acc.add_expose(variant.name, variant.to_ref)
              end
              .add_expose(name, symbol.to_ref)
              .then { Result[it, []] }
          end

          Result[
            entry,
            [Error::ExposedTypeNotFound.new(entry, span, name:)],
          ]
        end

        def lookup_and_expose_value(entry, name, span)
          symbol = entry.lookup_value(name)

          if symbol
            return entry
              .add_expose(name, symbol.to_ref)
              .then { Result[it, []] }
          end

          Result[
            entry,
            [Error::ExposedValueNotFound.new(entry, span, name:)],
          ]
        end
      end
    end
  end
end
