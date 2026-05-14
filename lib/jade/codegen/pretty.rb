module Jade
  module Codegen
    module Pretty
      extend self

      INDENT = "  "

      def newline(count = 1)
        "\n" * count
      end

      def indent(str, levels = 1)
        str.gsub(/^(?!$)/, INDENT * levels)
      end

      def block(header, body, footer = "end")
        body.empty? ? "#{header}\n#{footer}" : "#{header}\n#{indent(body)}\n#{footer}"
      end

      def lambda(params, body)
        multiline?(body) ? block("->(#{params}) {", body, "}") : "->(#{params}) { #{body} }"
      end

      def hash(pairs)
        pairs
          .map { |k, v| "#{k.inspect} => #{v}" }
          .join(', ')
          .then { "{ #{it} }" }
      end

      def array(items)
        "[#{items.join(', ')}]"
      end

      def multiline?(str)
        str.include?("\n")
      end
    end
  end
end
