require 'jade/frontend/symbol_resolution/keyed_call/validation'

module Jade
  module Frontend
    module SymbolResolution
      # The only resolver that swaps the node for a different AST shape.
      # Lowers `Foo(name: x, age: y)` into a positional FunctionCall:
      #   - struct constructor: FunctionCall(Foo, [x, y]) ordered by struct fields
      #   - keyed variant:      FunctionCall(V, [{a: x, b: y}]) anon record arg
      module KeyedCall
        extend self
        extend Helper

        def resolve(node, registry, current_entry)
          node => AST::KeyedCall(callee:, fields:)

          resolve_node(callee, registry, current_entry) => {
            node: callee_resolved, errors: callee_errors,
          }
          constructor = constructor_symbol(callee_resolved, registry)
          parent = constructor && registry.lookup(constructor.parent)

          fields
            .map { resolve_node(it, registry, current_entry) }
            .then { Result.sequence(it) }
            .add_errors(callee_errors)
            .add_errors(Validation.errors(
              node, fields, parent, constructor, registry, current_entry,
            ))
            .map { lower(node, callee_resolved, it, parent, constructor, registry) }
        end

        private

        def lower(node, callee, fields, parent, constructor, registry)
          case parent
          in Symbol::Struct
            Validation
              .expected_field_keys(parent, constructor, registry)
              .then { positional_struct_call(node, callee, fields, it) }

          in Symbol::Union
            variant_call(node, callee, fields)

          else
            node.with(callee:, fields:)
          end
        end

        def positional_struct_call(node, callee, fields, struct_keys)
          fields
            .to_h { [it.key, it.value] }
            .then { |fields_by_key| struct_keys.map { fields_by_key[it] }.compact }
            .then do
              AST::FunctionCall.new(
                callee:,
                args: it,
                infix: false,
                dictionaries: [],
                range: node.range,
              )
            end
        end

        def variant_call(node, callee, fields)
          AST::FunctionCall.new(
            callee:,
            args: [AST::RecordLiteral.new(fields:, range: node.range)],
            infix: false,
            dictionaries: [],
            range: node.range,
          )
        end

        def constructor_symbol(callee, registry)
          callee in AST::ConstructorReference or return nil

          case registry.lookup(callee.symbol)
          in Symbol::Constructor => constructor then constructor
          else nil
          end
        end
      end
    end
  end
end
