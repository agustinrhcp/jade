module Jade
  module Frontend
    module SemanticAnalysis
      module VariableReference
        extend self
        extend Helper

        def analyze(node, _registry, scope, entry)
          node => AST::VariableReference(name:)

          case scope.lookup(name)
          in nil
            Result
              .init(node.with(symbol: Symbol.var(name, node.range)), scope)
              .add_errors([Error::UndefinedVariable.new(entry.name, node.range, var_ref: name)])

          in symbol
            Result.init(node.with(symbol:), scope)
          end
        end
      end
    end
  end
end
