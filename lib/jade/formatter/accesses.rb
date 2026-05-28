module Jade
  module Formatter
    # The three `target.member`-style accesses. Each has a slightly
    # different `.name` shape (member is an Identifier, qualified is a
    # raw string), but the formatting is `<target>.<rendered name>`.

    module MemberAccess
      extend self
      extend Helper

      def format(node, indent:, source:)
        "#{format_node(node.target, source:)}.#{node.name.name}"
          .then(&and_indent(indent))
      end
    end

    module QualifiedAccess
      extend self
      extend Helper

      def format(node, indent:, source:)
        "#{format_node(node.target, source:)}.#{node.name}"
          .then(&and_indent(indent))
      end
    end

    module RecordAccess
      extend self
      extend Helper

      def format(node, indent:, source:)
        "#{format_node(node.target, source:)}.#{node.name.name}"
          .then(&and_indent(indent))
      end
    end
  end
end
