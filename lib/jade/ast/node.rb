module Jade
  module AST
    module Node
      @@_next_id = 0

      # Boilerplate added by Nodes.define alongside the AST-specific fields.
      # Excluded from child traversal so we don't iterate the `range` Range
      # as integers or descend into comment metadata.
      BOILERPLATE_FIELDS = %i[
        range symbol id
        leading_comments trailing_comments dangling_comments
        trailing_comma
      ].freeze

      def self.next_id
        @@_next_id += 1
      end

      # The comment block touching this node. A blank line above it means
      # a section banner, which documents the region and not this node.
      def doc(source)
        leading_comment_groups(source)
          .last
          &.then { follows_directly?(it.last, self, source) ? it : nil }
          &.then { it.map(&:value).join("\n") }
      end

      # Split wherever a blank line separates one block from the next.
      def leading_comment_groups(source)
        leading_comments
          .slice_when { |a, b| !follows_directly?(a, b, source) }
          .to_a
      end

      # Deepest descendant whose range covers `offset`, or self if no child
      # matches. Returns nil if this node's range is missing or doesn't
      # cover the offset.
      def find_at(offset)
        find_at_path(offset).last
      end

      # Path of nested nodes from self down to the deepest descendant
      # covering `offset`. Empty if self doesn't cover. Use this when you
      # need to consult ancestors — e.g. hover on `String` inside
      # `String.length(...)` needs the surrounding QualifiedAccess, not the
      # raw ConstructorReference.
      def find_at_path(offset)
        return [] unless range&.cover?(offset)

        (members - BOILERPLATE_FIELDS)
          .flat_map { public_send(it) }
          .flat_map { it.is_a?(Array) ? it : [it] }
          .filter_map { it.is_a?(Node) ? it.find_at_path(offset) : nil }
          .reject(&:empty?)
          .first
          .then { [self] + (it || []) }
      end

      private

      def follows_directly?(first, second, source)
        line_of(second.range.begin, source) -
          line_of(first.range.end - 1, source) == 1
      end

      def line_of(pos, source)
        source
          .line_starts
          .bsearch_index { it > pos }
          .then { it ? it - 1 : source.line_starts.length - 1 }
      end
    end
  end
end
