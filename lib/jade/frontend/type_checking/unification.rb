module Jade
  module Frontend
    module TypeChecking
      module Unification
        extend self

        def unify(type1, type2)
          case [type1, type2]
          in [Type::Application, Type::Application]
            unify_many(type1.args, type2.args)
              .then do |args_r|
                unify(type1.constructor, type2.constructor)
                  .on_err { args_r.and_then { Err[it] } }
                  .and_then { |sub| args_r.map_both { it.compose(sub) } }
              end
              .map_error do |final_sub|
                UnificationError.new(
                  final_sub.apply(type1),
                  final_sub.apply(type2),
                )
              end

          in [Type::Var, _]
            Ok[Substitution.new.bind(type1.name, type2)]

          in [_, Type::Var]
            unify(type2, type1)

          in [Type::Function, Type::Function]
            unless type1.args.size == type2.args.size
              return Err[UnificationError.new(type1, type2)]
            end

            unify_many(type1.args, type2.args)
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

          in [Type::AnonymousRecord, Type::AnonymousRecord]
            f1 = type1.field_names
            f2 = type2.field_names

            if type1.closed? && (f2 - f1).any?
              return Err[UnificationError.new(type1, type2)]
            end

            if type2.closed? && (f1 - f2).any?
              return Err[UnificationError.new(type1, type2)]
            end

            unify_shared_fields(type1, type2)
              .map_error do |final_sub|
                UnificationError.new(
                  final_sub.apply(type1),
                  final_sub.apply(type2),
                )
              end

          else
            Err[UnificationError.new(type1, type2)]
          end
        end

        private

        def unify_shared_fields(type1, type2)
          shared_fields = type1.field_names & type2.field_names
          fields1 = type1.fields
          fields2 = type2.fields

          # TODO: Reuse unify_many
          shared_fields
            .reduce(Ok[Substitution.new]) do |subs_r, key|
              sub = case subs_r
              in Ok(sub)
                sub
              in Err(sub)
                sub
              end

              case unify(fields1[key], fields2[key])
              in Err
                next subs_r.and_then { Err[it] }
              in Ok(k_sub)
                subs_r.map_both { it.compose(k_sub) }
              end
            end
        end

        def unify_many(types1, types2)
          types1
            .zip(types2)
            .reduce(Ok[Substitution.new]) do |subs_r, args|
              sub = case subs_r
              in Ok(sub)
                sub
              in Err(sub)
                sub
              end

              case unify(*args.map { sub.apply(it) })
              in Err
                next subs_r.and_then { Err[it] }
              in Ok(arg_sub)
                subs_r.map_both { it.compose(arg_sub) }
              end
            end
        end

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
