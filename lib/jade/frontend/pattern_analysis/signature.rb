module Jade
  module Frontend
    module PatternAnalysis
      # One shape a column's first pattern can take. `arg_types` are the
      # columns it opens up when a row is specialized on it.
      ConstructorCase = Data.define(:name, :arg_types) do
        def arity
          arg_types.size
        end

        def matches?(pattern)
          pattern in Constructor(constructor: ^(name))
        end

        def witness(args)
          Constructor[name, args]
        end
      end

      # A literal the rows mention. Types whose values are literals have no
      # enumerable set of these, so one is only ever split on because some row
      # asked for it by name.
      ValueCase = Data.define(:value) do
        def name
          value
        end

        def arity
          0
        end

        def arg_types
          []
        end

        def matches?(pattern)
          pattern in Literal(value: ^(value))
        end

        def witness(_args)
          Literal[value]
        end
      end

      # A stretch of the integer line no pattern in the column divides any
      # further, so it is either wholly matched or wholly missed.
      IntervalCase = Data.define(:from, :to) do
        def arity
          0
        end

        def arg_types
          []
        end

        def matches?(pattern)
          case pattern
          in Interval then pattern.covers?(self)
          in Literal(value: Integer => n) then n == from && n == to
          else false
          end
        end

        def witness(_args)
          Interval[from, to]
        end
      end

      # The cases a column of a given type can be split into, and whether they
      # account for every value of that type. When they don't, a row headed by
      # a wildcard covers ground no case names, so the column cannot be
      # decided by splitting alone.
      Split = Data.define(:cases, :total) do
        def covering(head)
          cases.select { it.matches?(head) }
        end

        def touched_by?(heads)
          cases.any? { |kase| heads.any? { kase.matches?(it) } }
        end

        def covered_by?(heads)
          total && cases.any? &&
            cases.all? { |kase| heads.any? { kase.matches?(it) } }
        end
      end

      module Signature
        extend self

        UNIT = Split[[], true]
        OPEN = Split[[], false]

        def of(type, heads, env)
          case type
          in Type::Application(constructor: Type::Constructor(name:), args:)
            named(type, name, args, heads, env)

          else
            OPEN
          end
        end

        # No value of this type exists, so no row over it can be reached and
        # nothing about it can be missing.
        def uninhabited?(type)
          name_of(type) == 'Basics.Never'
        end

        # A single-shape type is destructured into its fields rather than split
        # into cases, so the columns behind it stay checkable.
        def expandable?(type, env)
          return true if type in Type::AnonymousRecord

          env.lookup_def(name_of(type)).is_a?(TypeChecking::StructDef)
        end

        def fields(type, env)
          case type
          in Type::AnonymousRecord(fields:) then fields
          else env.lookup_def(name_of(type)).body.fields
          end
        end

        private

        def name_of(type)
          case type
          in Type::Application(constructor: Type::Constructor(name:)) then name
          else nil
          end
        end

        def named(type, name, args, heads, env)
          case name
          in 'Basics.Bool'
            Split[
              [ConstructorCase['Basics.True', []], ConstructorCase['Basics.False', []]],
              true,
            ]

          in /^Tuple\.Tuple[2-4]$/
            Split[[ConstructorCase[name, args]], true]

          in 'List.List'
            args => [element]

            Split[
              [
                ConstructorCase['List.Nil', []],
                ConstructorCase['List.Cons', [element, type]],
              ],
              true,
            ]

          in 'Basics.Int'
            integers(heads)

          in 'Basics.Float' | 'String.String'
            OPEN

          else
            union(type, name, env)
          end
        end

        # Every bound in the column cuts the line in two, and the pieces
        # between consecutive cuts are the coarsest split that still lets each
        # pattern be answered whole. The pieces partition Int, so the result is
        # total even though Int cannot be enumerated: a stretch no pattern
        # names comes back as a gap rather than as an open column.
        def integers(heads)
          cuts = heads.flat_map { cuts_of(it) }.compact.uniq.sort

          return OPEN if cuts.empty?

          [nil, *cuts]
            .zip([*cuts.map { it - 1 }, nil])
            .map { |(from, to)| IntervalCase[from, to] }
            .then { Split[it, true] }
        end

        def cuts_of(head)
          case head
          in Interval(from: Integer | nil => from, to: Integer | nil => to)
            [from, to && to + 1]
          in Literal(value: Integer => n) then [n, n + 1]
          else []
          end
        end

        def union(type, name, env)
          type_def = env.lookup_def(name)

          # A type the user cannot destructure from here — reached through an
          # imported struct's field, or an opaque intrinsic. Any pattern they
          # can write against it is trivially exhaustive.
          return UNIT if type_def.nil? || type_def.opaque?
          return OPEN unless type_def.is_a?(TypeChecking::TypeDef)

          type_def
            .constructors
            .map { ConstructorCase[it.name, instantiate(it.args, type_def, type)] }
            .then { Split[it, true] }
        end

        def instantiate(args, type_def, type)
          args.map do |arg|
            next arg unless arg.is_a?(Type::Var)

            type_def
              .type_params
              .find_index { arg.name == it.name }
              .then { type.args.at(it) }
          end
        end
      end
    end
  end
end
