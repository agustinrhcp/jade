module Jade
  module Frontend
    module SemanticAnalysis
      module Literal
        extend self
        extend Helper

        def analyze(node, _registry, scope, _entry)
          node => AST::Literal(value:)

          symbol = case value
          in Integer then Symbol::TypeRef['Basics', 'Int']
          in TrueClass | FalseClass then Symbol::TypeRef['Basics', 'Bool']
          in String then Symbol::TypeRef['String', 'String']
          in Float then Symbol::TypeRef['Basics', 'Float']
          end

          Result.init(node.with(symbol:), scope)
        end
      end
    end
  end
end
