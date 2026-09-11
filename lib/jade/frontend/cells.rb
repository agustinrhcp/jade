module Jade
  module Frontend
    # A REPL input compiles as a module of its own, a cell. Only there may
    # `x = expr` stand at the top level: it becomes a zero-argument function
    # whose return type is inferred rather than declared, and later cells
    # import it like any other value.
    module Cells
      extend self

      def lift(entry, registry)
        return entry unless registry.cell?(entry.name)

        entry.ast => AST::Module(body:)

        body
          .expressions
          .map { binding?(it) ? to_declaration(it) : it }
          .then { entry.with(ast: entry.ast.with(body: body.with(expressions: it))) }
      end

      private

      def binding?(node)
        node in AST::Assign(pattern: AST::Pattern::Binding)
      end

      def to_declaration(node)
        node => AST::Assign(pattern: AST::Pattern::Binding(name:), expression:, range:)

        AST::FunctionDeclaration.new(
          name:,
          params: [],
          return_type: nil,
          body: AST::Body.new(expressions: [expression], range: expression.range),
          range:,
        )
      end
    end
  end
end
