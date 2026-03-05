module Jade
  module Frontend
    module TypeChecking
      module Unification
        extend self

        def unify(type1, type2, env)
          case [type1, type2]
          in [Type::Application, Type::Application]
            unify(type1.constructor, type2.constructor, env)
              .map_error { UnificationError.new(type1,type2) }
              .and_then do |cons|
                unify_many(type1.args, type2.args, env)
                  .map_error do |final_sub|
                    UnificationError.new(
                      final_sub.apply(type1),
                      final_sub.apply(type2),
                    )
                  end
              end

          in [Type::Var, _]
            if (type1.rigid? || type2.rigid?) && type1 != type2
              return Err[UnificationError.new(type1, type2)]
            end

            if type1.constraints.any?
              case type2
              in Type::Var
                return Substitution
                  .new
                  .bind(type2.id, type2.add_constraints(type1.constraints))
                  .bind(type1.id, type2)
                  .then { Ok[it] }

              in Type::Application(constructor:)
                missing_constraints = type1
                  .constraints
                  .select do |c|
                    env
                      .implementations[
                        [c.interface.qualified_name, constructor.name]
                      ].nil?
                  end
                
                return Err[UnificationError.new(type2, type2)] if missing_constraints.any?
              end

              Ok[Substitution.new.bind(type1.id, type2)]
            end

            Ok[Substitution.new.bind(type1.id, type2)]

          in [_, Type::Var]
            unify(type2, type1, env)
              .map_error(&:flip)

          in [Type::Function, Type::Function]
            unless type1.args.size == type2.args.size
              return Err[UnificationError.new(type1, type2)]
            end

            unify_many(type1.args, type2.args, env)
              .then do |args_r|
                unify(type1.return_type, type2.return_type, env)
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

            unify_shared_fields(type1, type2, env)
              .map_error do |final_sub|
                UnificationError.new(
                  final_sub.apply(type1),
                  final_sub.apply(type2),
                )
              end
              .and_then do |fields_r|
                if type1.open? && type2.open?
                  fresh_type = env.fresh

                  Type
                    .anonymous_record(type1.fields.merge(type2.fields), env.fresh)
                    .then { Substitution.new.bind(fresh_type.id, it)}
                    .bind(type1.row_var.id, fresh_type)
                    .bind(type2.row_var.id, fresh_type)
                    .compose(fields_r)
                    .then { Ok[it] }

                elsif type1.open?
                  unify(type1.row_var, type2, env)
                    .map { fields_r.compose(it) }

                elsif type2.open?
                  unify(type2.row_var, type1, env)
                    .map { fields_r.compose(it) }

                else
                  Ok[fields_r]
                end
              end

          in [Type::AnonymousRecord, Type::Application]
            expanded = env.lookup_def(type2.constructor.name)

            return Err[UnificationError.new(type1, type2)] unless expanded

            expanded
              .type_params.map(&:id).zip(type2.args).to_h
              .reduce(Substitution.new) do |acc, (k, v)|
                acc.bind(k, v)
              end
              .apply(expanded.body)
              .then { unify(type1, it, env) }
              .and_then { |body_r| unify(type1.row_var, type2, env).map { body_r.compose(it) } }
              .on_err { Err[UnificationError.new(type1, type2)] }
            

          in [Type::Application, Type::AnonymousRecord]
            unify(type2, type1, env)
              .map_error(&:flip)

          else
            Err[UnificationError.new(type1, type2)]
          end
        end

        private

        def unify_shared_fields(type1, type2, env)
          shared_fields = type1.field_names & type2.field_names
          fields1 = type1.fields
          fields2 = type2.fields

          shared_fields
            .reduce(Ok[Substitution.new]) do |subs_r, key|
              sub = case subs_r
              in Ok(sub)
                sub
              in Err(sub)
                sub
              end

              case unify(fields1[key], fields2[key], env)
              in Err
                next subs_r.and_then { Err[it] }
              in Ok(k_sub)
                subs_r.map_both { it.compose(k_sub) }
              end
            end
        end

        def unify_many(types1, types2, env)
          types1
            .zip(types2)
            .reduce(Ok[Substitution.new]) do |subs_r, args|
              sub = case subs_r
              in Ok(sub)
                sub
              in Err(sub)
                sub
              end

              case unify(*args.map { sub.apply(it) }, env)
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

          def flip
            old_expected = @expected
            @expected = @actual
            @actual = old_expected
            self
          end

          def message
            "Cannot unify #{expected} with #{actual}"
          end
        end
      end
    end
  end
end
