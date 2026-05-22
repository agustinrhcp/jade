module Jade
  module Frontend
    module SemanticAnalysis
      module PatternBinding
        extend self
        extend Helper

        def analyze(node, registry, scope, entry)
          node => AST::Pattern::Binding(name:)

          predicate_errors =
            if name.end_with?('?')
              [Error::PredicateNameNotAllowed.new(entry.name, node.range, name:)]
            else
              []
            end

          bind(scope, Symbol.var(name, node.range), entry)
            .add_errors(predicate_errors)
        end
      end
    end
  end
end
