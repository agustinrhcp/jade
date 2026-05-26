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
    end
  end
end
