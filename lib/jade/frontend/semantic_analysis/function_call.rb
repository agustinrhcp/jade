module Jade
  module Frontend
    module SemanticAnalysis
      module FunctionCall
        extend self
        extend Helper

        def analyze(node, registry, scope, entry)
          node => AST::FunctionCall(callee:, args:)

          analyze_many(args, registry, scope, entry) => { errors: args_errors }

          analyze_node(callee, registry, scope, entry)
            .add_errors(args_errors)
        end
      end
    end
  end
end
