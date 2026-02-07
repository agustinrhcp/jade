module Jade
  module Frontend
    module SemanticAnalysis
      module FunctionDeclaration
        extend self
        extend Helper

        def analyze(node, registry, scope)
          node => AST::FunctionDeclaration(name:, params:, body:, symbol:)

          annotation_errors = validate_symbol(symbol, error)

          params
            .reduce(SemanticAnalyzer::Result[scope, []]) do |acc, param|
              bind(acc.scope, param.name, Symbol.param(param.name))
                .add_errors(acc.errors)
            end
            .then do
              analyze_node(body, registry, it.scope)
                .add_errors(it.errors)
            end
              .add_errors(annotation_errors)
              .with(scope:)
        end

        private

        def validate_symbol(symbol, registry)
        end
      end
    end
  end
end
