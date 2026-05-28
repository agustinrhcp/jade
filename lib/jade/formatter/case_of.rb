module Jade
  module Formatter
    module CaseOf
      extend self
      extend Helper

      def format(node, indent:, source:)
        node => AST::CaseOf(expression:, branches:)

        branches_str = branches
          .map.with_index { |b, i| format_branch(b, branches, i, indent, source:) }
          .join("\n")

        [
          "case #{format_node(expression, source:)}".then(&and_indent(indent)),
          branches_str,
          "end".then(&and_indent(indent)),
        ].join("\n")
      end

      # The last branch is rendered as `else` when its pattern is a
      # wildcard — purely sugar; the AST shape is the same.
      def format_branch(branch, all_branches, i, indent, source:)
        last_wildcard = i == all_branches.length - 1 &&
          branch.pattern.is_a?(AST::Pattern::Wildcard)

        CaseOfBranch.format(branch, indent:, source:, as_else: last_wildcard)
      end
    end
  end
end
