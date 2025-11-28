module Jade
  module ModuleLoader
    DependencyGraph = Data.define(:nodes) do
      def initialize(nodes: {})
        super
      end

      def size
        nodes.size
      end

      def empty?
        nodes.empty?
      end

      def add(node, imports)
        nodes
          .merge(node => imports.to_set.to_a)
          .then { with(nodes: it) }
      end
    end
  end
end
