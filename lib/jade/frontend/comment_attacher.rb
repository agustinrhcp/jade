module Jade
  module Frontend
    module CommentAttacher
      extend self

      SKIP_FIELDS = %i[range symbol id leading_comments trailing_comments dangling_comments].freeze

      def attach(ast, comments, source)
        return ast if comments.empty?

        collect_nodes(ast)
          .reject { |n| n.range.nil? }
          # Outermost first, so `x = f(y)` anchors on the Assign rather
          # than the pattern nested inside it.
          .sort_by { |n| [n.range.begin, -n.range.size] }
          .then { build_map(comments, it, source) }
          .then { reattach(ast, it) }
      end

      private

      def collect_nodes(node)
        node
          .to_h
          .reject { |field, _| SKIP_FIELDS.include?(field) }
          .values
          .flat_map { walk_collect(it) }
          .then { [node, *it] }
      end

      def walk_collect(val)
        case val
        in AST::Node then collect_nodes(val)
        in Array     then val.flat_map { walk_collect(it) }
        else              []
        end
      end

      def build_map(comments, sorted_nodes, source)
        comments
          .filter_map { classify(it, sorted_nodes, source) }
          .group_by(&:node_id)
          .transform_values { CommentGroup.from_comments(it) }
      end

      def classify(comment, sorted_nodes, source)
        comment_line = line_of(comment.range.begin, source)
        prev_node    = last_node_ending_before(comment.range.begin, sorted_nodes)
        next_node    = first_node_starting_after(comment.range.end, sorted_nodes)

        if prev_node && line_of(prev_node.range.end - 1, source) == comment_line
          CommentEntry::Trailing.new(node_id: prev_node.id, comment:)

        elsif next_node
          CommentEntry::Leading.new(node_id: next_node.id, comment:)

        else
          enclosing = smallest_enclosing(comment.range.begin, sorted_nodes)
          CommentEntry::Dangling.new(node_id: enclosing.id, comment:) if enclosing
        end
      end

      def line_of(pos, source)
        idx = source.line_starts.bsearch_index { |ls| ls > pos }
        idx ? idx - 1 : source.line_starts.length - 1
      end

      def last_node_ending_before(pos, sorted_nodes)
        sorted_nodes
          .select { |n| n.range.end <= pos }
          .last
      end

      def first_node_starting_after(pos, sorted_nodes)
        sorted_nodes
          .drop_while { |n| n.range.begin < pos }
          .find { |n| renders_own_comments?(n) }
      end

      # ModuleNode walks `body.expressions` directly, so a Body's own
      # leading comments reach no formatter and would be lost.
      def renders_own_comments?(node)
        !node.is_a?(AST::Body)
      end

      def smallest_enclosing(pos, sorted_nodes)
        sorted_nodes
          .select { |n| n.range.cover?(pos) }
          .min_by { |n| n.range.size }
      end

      def reattach(node, map)
        rebuilt_children = node
          .to_h
          .reject { |field, _| SKIP_FIELDS.include?(field) }
          .transform_values { walk_reattach(it, map) }

        node
          .with(
            **rebuilt_children,
            **((map[node.id]&.to_h || {}).transform_keys { :"#{it}_comments" }),
          )
      end

      def walk_reattach(val, map)
        case val
        in AST::Node then reattach(val, map)
        in Array     then val.map { walk_reattach(it, map) }
        else              val
        end
      end

      module CommentEntry
        Leading  = Data.define(:node_id, :comment)
        Trailing = Data.define(:node_id, :comment)
        Dangling = Data.define(:node_id, :comment)
      end

      CommentGroup = Data.define(:leading, :trailing, :dangling) do
        def self.from_comments(entries)
          by_type = entries.group_by(&:class)
          new(
            leading:  (by_type[CommentEntry::Leading]  || []).map(&:comment),
            trailing: (by_type[CommentEntry::Trailing] || []).map(&:comment),
            dangling: (by_type[CommentEntry::Dangling] || []).map(&:comment),
          )
        end
      end
    end
  end
end
