module Jade
  module Frontend
    module TypeChecking
      module Unification
        extend self

        def unify(type1, type2)
          case [type1, type2]
          in [Type::Var, _]
            Ok[Substitution.new.bind(type1.name, type2)]

          in [_, Type::Var]
            unify(type2, type1)

          in [Type::Function, Type::Function]
            unless type1.args.size == type2.args.size
              return Err[UnificationError.new(type1, type2)]
            end

            type1
              .args
              .zip(type2.args)
              .reduce(Ok[Substitution.new]) do |subs_r, args|
                case unify(*args)
                in Err
                  next subs_r.and_then { Err[it] }
                in Ok(arg_sub)
                  subs_r.map_both { it.compose(arg_sub) }
                end
               end
              .then do |args_r|
                unify(type1.return_type, type2.return_type)
                  .on_err { args_r.and_then { Err[it] } }
                  .and_then { |sub| args_r.map_both { it.compose(sub) } }
              end
              .map_error do |final_sub|
                UnificationError.new(
                  final_sub.apply(type1),
                  final_sub.apply(type2),
                )
              end

          in [Type::Constructor, Type::Constructor]
            type1 == type2 ?
              Ok[Substitution.new] :
              Err[UnificationError.new(type1, type2)]
          end
        end

        private

        class UnificationError
          attr_reader :expected, :actual

          def initialize(actual, expected)
            @actual = actual
            @expected = expected
          end

          def message
            "Cannot unify #{expected} with #{actual}"
          end
        end
      end
    end
  end
end
