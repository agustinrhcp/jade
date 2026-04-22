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
            .flat_map do |name, decls|
              decls.drop(1).map do |decl|
                Error::DuplicateFunctionDeclaration.new(entry.name, decl.range, name)
              end
            end

          analyze_many(expressions, registry, scope, entry)
            .add_errors(duplicate_errors)
        end
      end
    end
  end
end
