module Jade
  module ModuleLoader
    # A module is keyed by the name its file implies — imports resolve
    # `Shop.Cart` to `shop/cart.jd` and back. The wrapper takes the declared
    # name while every type reference inside takes the file's, so a mismatch
    # emits Ruby referring to a constant that was never defined.
    module ModuleName
      extend self

      def check(ast, source)
        return Ok[ast] unless ast.is_a?(AST::Module)

        source.to_module_name.then do |expected|
          ast.name == expected ? Ok[ast] : Err[mismatch(ast, source, expected)]
        end
      end

      private

      def mismatch(ast, source, expected)
        Diagnostics::List
          .empty
          .error(
            "Module is declared as `#{ast.name}` but `#{source.uri}` defines `#{expected}`.",
            source:,
            span: name_span(ast),
            label: "expected `#{expected}`",
          )
          .help("Rename it to `#{expected}`, or move the file to `#{path_for(ast.name)}`.")
      end

      # `module` is skipped during parsing, so the node starts at the name.
      def name_span(ast)
        ast.range.begin...(ast.range.begin + ast.name.length)
      end

      def path_for(module_name)
        module_name
          .split('.')
          .map { Source.snake_case(it) }
          .join('/')
          .then { "#{it}.jd" }
      end
    end
  end
end
