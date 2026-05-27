module Jade
  module Frontend
    module PatternAnalysis
      Matrix = Data.define(:rows, :types) do
        def self.wildcard(types)
          types
            .map { Wildcard[] }
            .then { [it] }
            .then { Matrix[it, types] }
        end

        def self.empty(types = [])
          self.new([], types)
        end

        def map
          rows
            .map { yield it }
            .then { with(rows: it) }
        end

        def include?(row)
          rows.include?(row)
        end

        def size
          rows.size
        end

        def empty?
          rows.empty?
        end

        def any?
          rows.any?
        end

        def concat(other)
          with(rows: rows + other.rows)
        end

        def missing_patterns(env, seen_recursive_types = ::Set.new)
          if types.empty?
            return rows.empty? ? Matrix[[[]], types] : Matrix.empty
          end

          type = types.first

          return Matrix.empty if never?(type)
          return Matrix.wildcard(types) if rows.empty?

          if infinite?(type) || type_var?(type) || seen_recursive_types.include?(type)
            matrix = default
              .missing_patterns(env, seen_recursive_types)

            matrix
              .map { [Wildcard[]] + it }

          elsif expandable?(type, env)
            expand(env).missing_patterns(env, seen_recursive_types)

          else
            new_seen = seen_recursive_types | ::Set[type]
            constructors_of(type, env)
              .reduce(Matrix.empty.with(types:)) do |acc, constructor|
                missing = specialize(constructor)
                  .missing_patterns(env, new_seen)

                missing
                  .map do |row|
                    new_args = row.take(constructor.args.size)
                    tail = row.drop(constructor.args.size)

                  [Constructor[constructor.name, new_args]] + tail
                end
                .then { acc.concat(it) }
              end
          end
        end

        protected

        def expandable?(type, env)
          case type
          in Type::AnonymousRecord
            true

          in Type::Application(constructor:)
            env.lookup_def(constructor.name).is_a?(TypeChecking::StructDef)

          else
            false
          end
        end

        def expand(env)
          type_fields = 
            case types.first
            in Type::AnonymousRecord(fields:)
              fields

            in Type::Application(constructor:)
              env.lookup_def(constructor.name).body.fields
            end

          map do |row|
            case row.first
            in Record(fields:)
              type_fields
                .map do |(k, v)|
                  fields[k] || Wildcard[]
                end + row.drop(1)

            in Wildcard
              type_fields.map { Wildcard[] } + row.drop(1)
            end
          end
            .with(types: type_fields.values + types.drop(1))
        end

        def constructors_of(type, env)
          case type
          in Type::Application(constructor: Type::Constructor(name: 'Basics.Bool'))
            [
              TypeChecking::ConstructorDef['Basics.True', 'Basics.Bool', []],
              TypeChecking::ConstructorDef['Basics.False', 'Basics.Bool', []],
            ]
          in Type::Application(constructor: Type::Constructor(name: /^Tuple\.Tuple([2-4])$/ => name))
            n = name[-1].to_i
            [TypeChecking::Definition.constructor(name, name, Array.new(n) { env.fresh })]

          in Type::Application(constructor: Type::Constructor(name: 'List.List'), args: [elem_type])
            [
              TypeChecking::ConstructorDef['List.Nil',  'List.List', []],
              TypeChecking::ConstructorDef['List.Cons', 'List.List', [elem_type, type]],
            ]

          else
            type_def = env.lookup_def(type.constructor.name)

            # Type the user can't destructure from here (transitively reached
            # through an imported struct field, or opaque intrinsic) —
            # any pattern they can write is trivially exhaustive.
            return [] if type_def.nil? || type_def.opaque?

            type_def
              .constructors
              .map do |con|
                con
                  .args
                  .map do |arg|
                    if type_var?(arg)
                      type_def
                        .type_params
                        .find_index { arg.name == it.name }
                        .then { type.args.at(it) }

                    else
                      arg
                    end
                  end
                .then { con.with(args: it) }
              end
          end
        end

        def specialize(constructor)
          rows
            .filter_map do |cols|
              case cols.first
              in Literal(value:)
                next [] + cols.drop(1) if value == false && "Basics.False" == constructor.name
                next [] + cols.drop(1) if value == true && "Basics.True" == constructor.name

              in Constructor(constructor: cons_name, args:)
                args + cols.drop(1) if cons_name == constructor.name

              in Wildcard
                constructor.args.map { Wildcard[] } + cols.drop(1)

              end
            end
            .then { with(rows: it) }
            .then { it.with(types: constructor.args) }
        end

        def default
          rows
            .select { it.first.wildcard? }
            .map { it.drop(1) }
            .then { with(rows: it) }
            .with(types: types.drop(1))
        end

        def add(columns)
          with(rows: rows.concat(columns))
        end

        private

        def never?(type)
          case type
          in Type::Application(constructor: Type::Constructor(name: 'Basics.Never'))
            true
          else
            false
          end
        end

        def type_var?(type)
          type.is_a?(Type::Var)
        end

        def infinite?(type)
          case type
          in Type::Function
            true

          in Type::Application(constructor:)
            case constructor
            in Type::Constructor(name: 'Basics.Int') then true
            in Type::Constructor(name: 'Basics.Float') then true
            in Type::Constructor(name: 'String.String') then true
            else
              false
            end

          else
            false
          end
        end
      end
    end
  end
end
