module Jade
  module Formatter
    # `name = expr` and `name <- task` — same shape, different operator.

    module Assign
      extend self
      extend Helper

      def format(node, indent:, source:)
        node => AST::Assign(pattern:, expression:)

        "#{format_pattern(pattern)} = #{format_node(expression, source:)}"
          .then(&and_indent(indent))
      end
    end

    module Bind
      extend self
      extend Helper

      def format(node, indent:, source:)
        node => AST::Bind(pattern:, expression:)

        "#{format_pattern(pattern)} <- #{format_node(expression, source:)}"
          .then(&and_indent(indent))
      end
    end
  end
end
