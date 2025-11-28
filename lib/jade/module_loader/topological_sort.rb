module Jade
  module ModuleLoader
    module TopologicalSort
      extend self

      def sort(graph)
        graph
          .nodes
          .keys
          .reduce([[], [], []]) { |state, node| visit(graph, state, node) }
          .first
      end

      private

      def visit(graph, state, node)
        visited, visiting, stack = state

        return state if visited.include?(node)
        raise CycleDependencyError.new(stack + [node]) if visiting.include?(node)

        new_visited, new_visiting, new_stack = graph
          .nodes[node]
          .reduce([visited, visiting + [node], stack + [node]]) do |new_state, neighbor|
            visit(graph, new_state, neighbor)
          end

        [new_visited + [node], new_visiting - [node], new_stack[0...-1]]
      end
    end

    class CycleDependencyError < StandardError
      attr_reader :cycle_path

      def initialize(cycle_path)
        @cycle_path = cycle_path
        super("Cycle detected in module dependencies: #{cycle_path.join(' -> ')}")
      end
    end
  end
end
