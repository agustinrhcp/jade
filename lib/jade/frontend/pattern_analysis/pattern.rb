module Jade
  module Frontend
    module PatternAnalysis
      Wildcard = Data.define do
        def wildcard?
          true
        end

        def args
          []
        end

        def to_s
          '_'
        end
      end

      Literal = Data.define(:value) do
        def wildcard?
          false
        end

        def args
          []
        end

        def to_s
          value.inspect
        end
      end

      Constructor = Data.define(:constructor, :args) do
        def wildcard?
          false
        end

        def to_s
          if constructor.start_with?('Tuple.')
            "(#{args.map(&:to_s).join(', ')})"
          else
            name = constructor.split('.').last
            args.empty? ? name : "#{name}(#{args.map(&:to_s).join(', ')})"
          end
        end
      end

      Record = Data.define(:fields) do
        def wildcard?
          false
        end

        def args
          []
        end

        def to_s
          fields
            .map { |k, v| "#{k}: #{v}" }
            .join(', ')
            .then { "{ #{it} }" }
        end
      end

      # An inclusive span of integers. A nil bound is unbounded on that side.
      Interval = Data.define(:from, :to) do
        def wildcard?
          false
        end

        def args
          []
        end

        def covers?(other)
          (from.nil? || (other.from && other.from >= from)) &&
            (to.nil? || (other.to && other.to <= to))
        end

        def to_s
          case [from, to]
          in [nil, nil] then '_'
          in [n, ^n] then n.to_s
          else "#{from}..#{to}"
          end
        end
      end

      module Pattern
        extend self

        def from_node(node)
          case node
          in AST::Pattern::Record(fields:)
            fields
              .to_h { [it.name, from_node(it.pattern)] }
              .then { Record[it] }

          in AST::Pattern::Constructor(constructor:, patterns:)
            patterns
              .map { from_node(it) }
              .then { Constructor[constructor.symbol.qualified_name, it] }

          # `[x, y | xs]` and `[x, y]` are the same Cons/Nil spine the checker
          # already knows how to split.
          in AST::Pattern::List(patterns:, rest:)
            patterns
              .map { from_node(it) }
              .reverse
              .reduce(rest ? Wildcard[] : Constructor['List.Nil', []]) do |acc, head|
                Constructor['List.Cons', [head, acc]]
              end

          in AST::Pattern::Binding | AST::Pattern::Wildcard
            Wildcard[]

          in AST::Pattern::Literal(literal: { value: true })
            Constructor['Basics.True', []]

          in AST::Pattern::Literal(literal: { value: false })
            Constructor['Basics.False', []]

          in AST::Pattern::Literal(literal: { value: })
            Literal[value]
          end
        end
      end
    end
  end
end
