module Jade
  module Formatter
    module Exposing
      extend self
      extend Helper

      def format(node, indent: 0)
        case node
        in AST::ExposeAll
          "exposing (..)"

        in AST::ExposeNone | nil
          ""

        in AST::ExposeList(items:, trailing_comma:)
          item_strs = sort(items).map { format_item(it) }
          inline    = "exposing (#{item_strs.join(', ')})"

          if trailing_comma || too_long?(inline, indent)
            inner = item_strs.map { "#{INDENT * (indent + 1)}#{it}," }.join("\n")
            "exposing (\n#{inner}\n#{INDENT * indent})"
          else
            inline
          end
        end
      end

      # Types and constructors first, then values — both alphabetised.
      def sort(items)
        items.sort_by do |item|
          case item
          in AST::ExposeType | AST::ExposeTypeExpand then [0, item.name]
          in AST::ExposeValue then [1, item.name]
          end
        end
      end

      def format_item(node)
        case node
        in AST::ExposeValue(name:)      then name
        in AST::ExposeType(name:)       then name
        in AST::ExposeTypeExpand(name:) then "#{name}(..)"
        in AST::ExposeAs(as:)           then as
        end
      end
    end
  end
end
