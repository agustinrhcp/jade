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

        def missing_patterns(env)
          if types.empty?
            return rows.empty? ? Matrix[[[]], types] : Matrix.empty
          end

          type = types.first

          return Matrix.empty if never?(type)
          return Matrix.wildcard(types) if rows.empty?

          heads = head_constructors

          if infinite?(type) || type_var?(type)
            unmatched_column(env)

          elsif expandable?(type, env)
            expand(env).missing_patterns(env)

          elsif heads.empty?
            unmatched_column(env)

          else
            constructors_of(type, env)
              .reduce(Matrix.empty.with(types:)) do |acc, constructor|
                witnesses(constructor, env, heads.include?(constructor.name))
                  .then { acc.concat(it) }
              end
          end
        end

        protected

        # Nothing in this column narrows anything — a type with no constructors
        # to enumerate, or one every row left open. Whatever is missing lives in
        # the columns after it.
        def unmatched_column(env)
          default
            .missing_patterns(env)
            .map { [Wildcard[]] + it }
        end

        # A constructor the first column matches is explored by specializing on
        # it. One it never matches can only be missing as a whole, so its
        # witnesses come from the rows that would have covered it — the ones
        # headed by a wildcard. Recursing there instead of into the constructor
        # is what keeps a recursive type from expanding forever.
        def witnesses(constructor, env, matched)
          return Matrix.empty if constructor.args.any? { never?(it) }

          arity = constructor.args.size

          if matched
            specialize(constructor)
              .missing_patterns(env)
              .map { [Constructor[constructor.name, it.take(arity)]] + it.drop(arity) }

          else
            default
              .missing_patterns(env)
              .map { [Constructor[constructor.name, Array.new(arity) { Wildcard[] }]] + it }
          end
        end

        def head_constructors
          rows.filter_map { head_constructor(it.first) }
        end

        def head_constructor(pattern)
          case pattern
          in Constructor(constructor: name) then name
          in Literal(value: true) then 'Basics.True'
          in Literal(value: false) then 'Basics.False'
          in Literal | Record | Wildcard then nil
          end
        end

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
          in Type::Application(constructor: Type::Constructor(name: /^Tuple\.Tuple[2-4]$/ => name), args:)
            [TypeChecking::Definition.constructor(name, name, args)]

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
            .then { it.with(types: constructor.args + types.drop(1)) }
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
