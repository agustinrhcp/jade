module Jade
  module Frontend
    module SemanticAnalysis
      module FunctionDeclaration
        extend self
        extend Helper

        def analyze(node, registry, scope, entry)
          node => AST::FunctionDeclaration(name:, body:, params:, symbol:)

          annotation_errors = validate_type_symbol(symbol, registry, entry)

          params
            .reduce(Result[scope, []]) do |acc, param|
              bind(acc.scope, Symbol.param(param.name, param.range), entry)
                .add_errors(acc.errors)
            end
            .then do
              analyze_node(body, registry, it.scope, entry)
                .add_errors(it.errors)
            end
              .add_errors(annotation_errors)
              .with(scope:)
        end
      end
    end
  end
end
