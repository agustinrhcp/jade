module Jade
  module Frontend
    module SemanticAnalysis
      module ModuleNode
        extend self
        extend Helper

        def analyze(node, registry, scope, entry)
          node => AST::Module(body:, exposing:)

          exposing_errors = case exposing
          in AST::ExposeNone
            [Error::MissingExposingClause.new(entry.name, 0..0)]
          else
            []
          end

          Result
            .combine(node, scope:,
              body: analyze_node(body, registry, scope, entry),
            )
            .add_errors(exposing_errors)
        end
      end
    end
  end
end
