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

          if fields.any? { it.value.is_a?(AST::Placeholder) }
            return partially_applied(
              node, callee, fields, parent, constructor, registry, scope, entry, callee_r
            )
          end

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

        # Lowered before the fields are analyzed, so the placeholders are
        # still bare AST and `Placeholder.lift` can turn the call into a
        # lambda — the same route a positional partial application takes.
        def partially_applied(node, callee, fields, parent, constructor, registry, scope, entry, callee_r)
          # A positional variant has no field names at all, so every key is
          # also an unknown field — three errors for one mistake. The
          # placeholder error is the one that explains it.
          errors = placeholder_errors(fields, parent, constructor, entry)
            .then { it.any? ? it : Validation.errors(node, fields, parent, constructor, registry, entry) }

          return Result[node, callee_r.errors + errors, scope] if errors.any?

          named, params = name_placeholders(fields)

          lower(node, callee, named, parent, constructor, registry)
            .then { wrap_in_lambdas(it, params, node.range) }
            .then { analyze_node(it, registry, scope, entry) }
            .then { Result[it.node, callee_r.errors + it.errors, scope] }
        end

        # Named in the order the fields were written, not the order the
        # struct declares them, so `Point(y: _, x: _)` takes y first.
        def name_placeholders(fields)
          fields.reduce([[], []]) do |(named, params), field|
            case field.value
            in AST::Placeholder
              Codegen::Helpers.param_synthetic_name(params.size).then do |name|
                [named + [field.with(value: AST::VariableReference[name, nil])], params + [name]]
              end

            else
              [named + [field], params]
            end
          end
        end

        def wrap_in_lambdas(call, params, range)
          params
            .reverse
            .reduce(call) do |body, name|
              AST::Lambda[[AST::Pattern::Binding[name, nil]], AST::Body[[body], nil], range]
            end
        end

        # No constructor means the callee isn't one — a keyed call on a plain
        # function, which Validation reports on its own terms.
        def placeholder_errors(fields, parent, constructor, entry)
          return [] if constructor.nil? || parent.is_a?(Symbol::Struct)

          fields
            .select { it.value.is_a?(AST::Placeholder) }
            .map do
              Error::PlaceholderNotAllowed.new(
                entry.name,
                it.range,
                field: it.key,
                name: constructor.name,
                keyed: keyed_variant?(constructor),
              )
            end
        end

        def keyed_variant?(constructor)
          constructor in Symbol::Constructor(args: [Symbol::RecordType])
        end

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
