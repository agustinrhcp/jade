module Jade
  module Frontend
    module SemanticAnalysis
      module Body
        extend self
        extend Helper

        def analyze(node, registry, scope, entry)
          node => AST::Body(expressions:)

          duplicate_errors = expressions
            .select { it.is_a?(AST::FunctionDeclaration) }
            .group_by(&:name)
            .filter_map do |name, decls|
              next nil if decls.size < 2

              first, *rest = decls
              Error::DuplicateFunctionDeclaration.new(
                entry.name,
                first.range,
                name,
                duplicate_spans: rest.map(&:range),
              )
            end

          analyze_in_sequence(expressions, registry, scope, entry)
            .add_errors(duplicate_errors)
            .map_node { node.with(expressions: it) }
        end
      end
    end
  end
end
