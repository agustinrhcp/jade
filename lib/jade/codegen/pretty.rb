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

      # `callee(a, b, c)` on one line when it fits, multi-line with trailing
      # comma when it doesn't or when an arg is already multi-line. Pass
      # `open:`/`close:` to emit `Struct[a, b, c]`-shaped construction.
      def call(callee, args, width: 80, open: '(', close: ')')
        "#{callee}#{open}#{args.join(', ')}#{close}".then do |oneline|
          if oneline.length <= width && args.none? { multiline?(it) }
            oneline
          else
            "#{callee}#{open}\n#{indent(args.join(",\n"))},\n#{close}"
          end
        end
      end

      def multiline?(str)
        str.include?("\n")
      end
    end
  end
end
