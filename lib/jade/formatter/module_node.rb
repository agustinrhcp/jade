module Jade
  module Formatter
    module ModuleNode
      extend self
      extend Helper

      def format(node, indent:, source:)
        node => AST::Module(name:, exposing:, body:)

        chunks = body.expressions
          .chunk_while { |a, b|
            (a in AST::ImportDeclaration) && (b in AST::ImportDeclaration)
          }
          .map { |group|
            group.map { format_node(it, indent:, source:) }.join("\n")
          }

        header = "module #{name} #{format_exposing(exposing)}"
        # Two blank lines between top-level chunks so def-to-def boundaries
        # don't blur with blank lines inside a def body. Module header to
        # the first chunk stays one blank line.
        chunks.empty? ? header : "#{header}\n\n#{chunks.join("\n\n\n")}"
      end
    end
  end
end
