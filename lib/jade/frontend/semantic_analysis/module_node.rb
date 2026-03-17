module Jade
  module Frontend
    module SemanticAnalysis
      module ModuleNode
        extend self
        extend Helper

        def analyze(node, registry, scope, entry)
          node => AST::Module(body:, exposing:)

          case exposing
          in AST::ExposeNone
            Result[scope, [Error::MissingExposingClause.new(entry&.name, 0..0)]]
          else
            Result[scope, []]
          end
            .then { analyze_node(body, registry, it.scope, entry).add_errors(it.errors) }
        end
      end
    end
  end
end
