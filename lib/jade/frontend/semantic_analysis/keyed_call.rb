module Jade
  module Frontend
    module SemanticAnalysis
      # Lowers `Foo(name: x, age: y)` into a positional FunctionCall:
      #   - struct constructor: FunctionCall(Foo, [x, y]) ordered by struct fields
      #   - keyed variant:      FunctionCall(V, [{a: x, b: y}]) anon record arg
      module KeyedCall
        extend self
        extend Helper

        def analyze(node, registry, scope, entry)
          node => AST::KeyedCall(callee:, fields:)

          callee_r = analyze_node(callee, registry, scope, entry)
          callee_resolved = callee_r.node
          constructor = constructor_symbol(callee_resolved, registry)
          parent = constructor && registry.lookup(constructor.parent)

          fields_r = analyze_in_parallel(fields, registry, scope, entry)
          fields_resolved = fields_r.node

          validation_errors = Validation.errors(
            node, fields_resolved, parent, constructor, registry, entry,
          )

          lowered = lower(node, callee_resolved, fields_resolved, parent, constructor, registry)

          Result[
            lowered,
            callee_r.errors + fields_r.errors + validation_errors,
            scope,
          ]
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
