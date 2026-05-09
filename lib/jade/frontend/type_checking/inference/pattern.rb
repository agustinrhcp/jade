module Jade
  module Frontend
    module TypeChecking
      module Inference
        module Pattern
          extend Helpers
          extend self

          def infer(pattern, registry, state, expected)
            case pattern
            in AST::Pattern::Record(fields:, symbol:)
              fields_state, fields_result = fields
                .reduce([state, Result.accumulator]) do |(state_acc, result_acc), field|
                  st, rs = Expected
                    .infer(state_acc.fresh)
                    .then { infer(field.pattern, registry, state_acc, it) }

                  [st, result_acc.add(rs)]
                end

              fields
                .map(&:name)
                .zip(fields_result.types)
                .to_h
                .then { Type.anonymous_record(it, state.fresh) }
                .then { Result.init(it) }
                .then do
                  fields_state
                    .unify_result(it, expected.type, &type_error(state, pattern))
                end

            in AST::Pattern::Literal(literal:)
              new_state, literal_result = check(literal, registry, state, expected)
              new_state.unify_result(literal_result, expected.type, &type_error(state, pattern))

            in AST::Pattern::Wildcard
              Result
                .init(state.fresh)
                .then { state.unify_result(it, expected.type) }

            in AST::Pattern::Binding(name:)
              state
                .bind(name, Scheme.mono(expected.type))
                .then { it.unify_result(Result.init(it.fresh), expected.type) }

            in AST::Pattern::List(patterns:, rest:)
              elem_type = state.fresh
              list_type = Type.list.apply([elem_type])

              heads_state = patterns
                .reduce(state) do |acc, pat|
                  infer(pat, registry, acc, Expected.check(elem_type)).first
                end

              after_rest_state =
                case rest
                in AST::Pattern::Binding(name:)
                  generalize(heads_state.env, list_type, [])
                    .then { heads_state.bind(name, it) }

                in AST::Pattern::Wildcard | nil
                  heads_state
                end

              Result
                .init(list_type)
                .then do
                  after_rest_state
                    .unify_result(
                      it,
                      expected.type,
                      &type_error(after_rest_state, pattern)
                    )
                end

            in AST::Pattern::Constructor(symbol:, patterns: [])
              state.env.lookup(symbol.qualified_name) => { type: constructor_type }

              state.unify_result(
                Result.init(constructor_type),
                expected.type,
                &type_error(state, pattern)
              )

            in AST::Pattern::Constructor(symbol:, patterns:)
              state.env.lookup(symbol.qualified_name) => { type: constructor_type }

              patterns_state, patterns_result = constructor_type
                .args
                .zip(patterns)
                .reduce([state, Result.accumulator]) do |(acc_state, acc_result), (inner_expected, pat)|
                  new_state, result = Expected
                    .check(inner_expected)
                    .then { infer(pat, registry, acc_state, it) }

                  [new_state, acc_result.add(result)]
                end

              patterns_result.types
                .then { Type.function(it, expected.type) }
                .then { Result.init(it) }
                .then do
                  patterns_state
                    .unify_result(it, constructor_type) do |error|
                      Error::PatternTypeMismatch.new(
                        state.env.entry_name, pattern.range,
                        expected: error.expected.return_type,
                        actual:   error.actual.return_type,
                      )
                    end
                end
                .then { |(state, result)| [state, result.map(&:return_type)] }
            end
          end

          private

          def type_error(state, pattern)
            ->(error) do
              Error::PatternTypeMismatch.new(
                state.env.entry_name, pattern.range,
                expected: error.expected, actual: error.actual,
              )
            end
          end
        end
      end
    end
  end
end
