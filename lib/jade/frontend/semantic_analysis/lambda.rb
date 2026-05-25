module Jade
  module Frontend
    module SemanticAnalysis
      module Lambda
        extend self
        extend Helper

        def analyze(node, registry, scope, entry)
          node => AST::Lambda(params:, body:)

          params_r = analyze_in_sequence(params, registry, scope, entry)

          Result
            .combine(node, scope:,
              params: params_r,
              body: analyze_node(body, registry, params_r.scope, entry),
            )
            .map_node { it.with(symbol: Symbol::Lambda[params.size]) }
        end
      end
    end
  end
end
