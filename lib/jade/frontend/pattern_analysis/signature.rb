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

      # The cases a column of a given type can be split into, and whether they
      # account for every value of that type. When they don't, a row headed by
      # a wildcard covers ground no case names, so the column cannot be
      # decided by splitting alone.
      Split = Data.define(:cases, :total) do
        def find(name)
          cases.find { it.name == name }
        end

        def touched_by?(names)
          cases.any? { names.include?(it.name) }
        end

        def covered_by?(names)
          total && cases.any? && cases.all? { names.include?(it.name) }
        end
      end

      module Signature
        extend self

        UNIT = Split[[], true]
        OPEN = Split[[], false]

        def of(type, env)
          case type
          in Type::Application(constructor: Type::Constructor(name:), args:)
            named(type, name, args, env)

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

        def named(type, name, args, env)
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

          in 'Basics.Int' | 'Basics.Float' | 'String.String'
            OPEN

          else
            union(type, name, env)
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
