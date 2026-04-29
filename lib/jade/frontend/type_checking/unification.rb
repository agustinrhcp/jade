module Jade
  module Frontend
    module TypeChecking
      module Unification
        extend self

        Context = Data.define(:rigid_vars) do
          def self.empty
            new([])
          end

          def rigid?(type)
            rigid_ids = rigid_vars.map(&:id).to_set
            type.unbound_vars.any? { rigid_ids.include?(it.id) }
          end
        end

        def unify(type1, type2, env, ctx = Context.empty)
          case [type1, type2]
          in [Type::Application, Type::Application]
            case [type1.constructor, type2.constructor]
            in [Type::Var, _] if type1.args.length < type2.args.length
              unify_partial(type1, type2, env, ctx)
                .map_error { UnificationError.new(type1, type2) }

            in [_, Type::Var] if type2.args.length < type1.args.length
              unify_partial(type2, type1, env, ctx)
                .map_error { UnificationError.new(type1, type2) }

            else
              unify(type1.constructor, type2.constructor, env, ctx)
                .map_error { UnificationError.new(type1, type2) }
                .and_then do |cons|
                  unify_many(type1.args.map { cons.apply(it) }, type2.args.map { cons.apply(it) }, env, ctx)
                    .map_both { cons.compose(it) }
                    .map_error do |final_sub|
                      UnificationError.new(
                        final_sub.apply(type1),
                        final_sub.apply(type2),
                      )
                    end
                end
            end

          in [Type::Var, _]
            return Ok[Substitution.new] if type1 == type2

            if (ctx.rigid?(type1) || ctx.rigid?(type2)) && type1 != type2
              return Err[UnificationError.new(type1, type2)]
            end

            return Err[UnificationError.new(type1, type2)] if occurs_in?(type1, type2)

            Ok[Substitution.new.bind(type1.id, type2)]

          in [_, Type::Var]
            unify(type2, type1, env, ctx)
              .map_error(&:flip)

          in [Type::Function, Type::Function]
            unless type1.args.size == type2.args.size
              return Err[UnificationError.new(type1, type2)]
            end

            unify_many(type1.args, type2.args, env, ctx)
              .then do |args_r|
                args_sub = substitution_of(args_r)
                unify(args_sub.apply(type1.return_type), args_sub.apply(type2.return_type), env, ctx)
                  .on_err { args_r.and_then { Err[it] } }
                  .and_then { |sub| args_r.map_both { it.compose(sub) } }
              end
              .map_error do |final_sub|
                UnificationError.new(
                  final_sub.apply(type1),
                  final_sub.apply(type2),
                  final_sub,
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

            unify_shared_fields(type1, type2, env, ctx)
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
                  unify(type1.row_var, type2, env, ctx)
                    .map { fields_r.compose(it) }

                elsif type2.open?
                  unify(type2.row_var, type1, env, ctx)
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
              .then { unify(type1, it, env, ctx) }
              .and_then { |body_r| unify(type1.row_var, type2, env, ctx).map { body_r.compose(it) } }
              .on_err { Err[UnificationError.new(type1, type2)] }
            

          in [Type::Application, Type::AnonymousRecord]
            unify(type2, type1, env, ctx)
              .map_error(&:flip)

          else
            Err[UnificationError.new(type1, type2)]
          end
        end

        private

        def occurs_in?(var, type)
          case type
          in Type::Var(id:)
            var.id == id

          in Type::Application(args:)
            occurs_in?(var, type.constructor) || args.any? { occurs_in?(var, it) }

          in Type::Function(args:, return_type:)
            args.any? { occurs_in?(var, it) } || occurs_in?(var, return_type)

          in Type::PartialApplication(constructor:, args:)
            occurs_in?(var, constructor) || args.any? { occurs_in?(var, it) }

          in Type::Constraint(type: inner)
            occurs_in?(var, inner)

          in Type::AnonymousRecord(fields:, row_var:)
            fields.values.any? { occurs_in?(var, it) } ||
              (row_var ? occurs_in?(var, row_var) : false)

          in Type::Constructor | Type::TypeUnit
            false
          end
        end

        def substitution_of(result)
          case result
          in Ok(sub) then sub
          in Err(sub) then sub
          end
        end

        def unify_partial(var_side, concrete_side, env, ctx)
          head, *tail = concrete_side.args
          partial_c   = tail.empty? ? concrete_side.constructor : Type::PartialApplication[concrete_side.constructor, tail]

          unify(var_side.constructor, partial_c, env, ctx)
            .and_then do |cons|
              unify_many(var_side.args.map { cons.apply(it) }, [cons.apply(head)], env, ctx)
                .map_both { cons.compose(it) }
            end
        end

        def unify_shared_fields(type1, type2, env, ctx)
          shared_fields = type1.field_names & type2.field_names
          fields1 = type1.fields
          fields2 = type2.fields

          shared_fields
            .reduce(Ok[Substitution.new]) do |subs_r, key|
              sub = substitution_of(subs_r)

              case unify(fields1[key], fields2[key], env, ctx)
              in Err
                next subs_r.and_then { Err[it] }
              in Ok(k_sub)
                subs_r.map_both { it.compose(k_sub) }
              end
            end
        end

        def unify_many(types1, types2, env, ctx)
          types1
            .zip(types2)
            .reduce(Ok[Substitution.new]) do |subs_r, args|
              args_r = args
                .map { substitution_of(subs_r).apply(it) }
                .then { unify(*it, env, ctx) }

              case args_r
              in Err
                next subs_r.and_then { Err[it] }

              in Ok(arg_sub)
                subs_r.map_both { it.compose(arg_sub) }
              end
            end
        end

        class UnificationError
          attr_reader :expected, :actual, :partial_sub

          def initialize(actual, expected, partial_sub = nil)
            @actual = actual
            @expected = expected
            @partial_sub = partial_sub || Substitution.new
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
