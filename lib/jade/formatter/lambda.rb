module Jade
  module Formatter
    module Lambda
      extend self
      extend Helper

      # Atoms (and a few near-atoms) that read fine on a single line
      # next to the lambda head. Everything else forces the multi-line
      # `{ body }` shape.
      INLINE_BODY = [
        AST::Literal, AST::CharLiteral, AST::VariableReference,
        AST::ConstructorReference, AST::FunctionCall, AST::RecordAccess,
        AST::MemberAccess, AST::InfixApplication, AST::RecordLiteral,
        AST::List, AST::Tuple, AST::Grouping, AST::RecordUpdate,
        AST::RecordUpdateSugar, AST::RecordAccessSugar,
      ].freeze

      def format(node, indent:, source:)
        node => AST::Lambda(params:, body:)

        head = format_head(params)

        if inline_body?(body)
          "#{head} { #{format_node(body.expressions.first, source:)} }"
            .then(&and_indent(indent))
        else
          [
            "#{head} {".then(&and_indent(indent)),
            format_node(body, indent: indent + 1, source:),
            "}".then(&and_indent(indent)),
          ].join("\n")
        end
      end

      def format_head(params)
        return "->" if params.empty?

        params
          .map { format_pattern(it) }
          .join(', ')
          .then { "(#{it}) ->" }
      end

      def inline_body?(body)
        body.expressions.length == 1 &&
          INLINE_BODY.any? { body.expressions.first.is_a?(it) }
      end
    end
  end
end
