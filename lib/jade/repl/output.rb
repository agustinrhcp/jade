module Jade
  module Repl
    class Output < Data.define(:colors)
      RED = "\e[31m".freeze
      DIM = "\e[2m".freeze
      RESET = "\e[0m".freeze

      def render(outcome)
        case outcome
        in Accepted(lines:)
          lines
            .map { text_of(it) }
            .join("\n")

        in Rejected(diagnostics:)
          Diagnostics::Renderer
            .new(colors:)
            .render_all(diagnostics)

        in Raised(error:)
          "#{paint('error:', RED)} #{description(error)}"
        end
      end

      private

      def text_of(line)
        return line.text unless line.type

        "#{line.text} #{paint(": #{line.type}", DIM)}"
      end

      def description(error)
        case error
        in Interrupt then 'interrupted'
        else "#{error.message} (#{error.class})"
        end
      end

      def paint(text, code)
        colors ? "#{code}#{text}#{RESET}" : text
      end
    end
  end
end
