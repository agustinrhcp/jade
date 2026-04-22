module Jade
  module Frontend
    module SemanticAnalysis
      module Lambda
        extend self
        extend Helper

        def analyze(node, registry, scope, entry)
          node => AST::Lambda(params:, body:)

          params
            .reduce(Result[scope, []]) do |acc, param|
              analyze_node(param, registry, acc.scope, entry)
                .add_errors(acc.errors)
            end
            .then do
              analyze_node(body, registry, it.scope, entry)
                .add_errors(it.errors)
            end
            .with(scope:)
        end
      end
    end
  end
end
