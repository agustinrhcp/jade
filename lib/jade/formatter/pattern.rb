module Jade
  module Formatter
    module Pattern
      extend self
      extend Helper

      def format(node, source: nil)
        case node
        in AST::Pattern::Wildcard
          "_"

        in AST::Pattern::Literal(literal:)
          format_node(literal, source:)

        in AST::Pattern::Binding(name:)
          name

        in AST::Pattern::Constructor(constructor:, patterns:)
          name = format_node(constructor, source:)

          if patterns.nil? || patterns.empty?
            name
          else
            patterns
              .map { format(it) }
              .join(', ')
              .then { "#{name}(#{it})" }
          end

        in AST::Pattern::Record(fields:)
          fields
            .map { format(it) }
            .join(", ")
            .then { "{ #{it} }" }

        in AST::Pattern::RecordField(name:, pattern: AST::Pattern::Binding(name: ^name))
          "#{name}:"

        in AST::Pattern::RecordField(name:, pattern:)
          "#{name}: #{format(pattern)}"

        in AST::Pattern::Tuple(patterns:)
          patterns
            .map { format(it) }
            .join(', ')
            .then { "(#{it})" }

        in AST::Pattern::List(patterns:, rest:)
          heads = patterns.map { format(it) }.join(', ')
          tail = case rest
            in AST::Pattern::Binding(name:) then " | #{name}"
            in AST::Pattern::Wildcard       then " | _"
            in nil                          then ""
            end

          "[#{heads}#{tail}]"
        end
      end
    end
  end
end
