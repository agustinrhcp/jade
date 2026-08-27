require 'jade/codegen/helpers'

module Jade
  module Frontend
    module Desugaring
      module Placeholder
        extend self
        extend Codegen::Helpers

        def lift(node)
          case node
          in AST::FunctionCall(args:)
            fill(node, args) { |filled| node.with(args: filled) }

          in AST::RecordLiteral(fields:)
            fill(node, fields.map(&:value)) do |filled|
              fields
                .zip(filled)
                .map { |field, value| field.with(value:) }
                .then { node.with(fields: it) }
            end
          end
        end

        private

        def fill(node, slots, &rebuild)
          return node unless slots.any?(AST::Placeholder)

          named(slots)
            .then { |filled, names| [rebuild.call(filled), names] }
            .then { |body, names| wrap_in_lambdas(body, names, node.range) }
        end

        def named(slots)
          slots.reduce([[], []]) do |(filled, names), slot|
            case slot
            in AST::Placeholder
              param_synthetic_name(names.size)
                .then { [filled + [AST::VariableReference[it, nil]], names + [it]] }

            else
              [filled + [slot], names]
            end
          end
        end

        def wrap_in_lambdas(body, names, range)
          names
            .reverse
            .reduce(body) do |inner, name|
              AST::Lambda[
                [AST::Pattern::Binding[name, nil]],
                AST::Body[[inner], nil],
                range,
              ]
            end
        end
      end
    end
  end
end
