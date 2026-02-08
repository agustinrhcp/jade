module Jade
  module Frontend
    module SemanticAnalysis
      module FunctionDeclaration
        extend self
        extend Helper

        def analyze(node, registry, scope)
          node => AST::FunctionDeclaration(name:, params:, body:, symbol:, return_type:)

          # annotation_errors = analyze_return_type(return_type, registry) + analyze_params(params, registry)
          annotation_errors = validate_type_symbol(symbol, registry)

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

        def validate_type_symbol(symbol, registry)
          case symbol
          in Symbol::ValueRef
            registry.lookup(symbol)
              .then { validate_type_symbol(it, registry) }

          in Symbol::Variable
            []

          in Symbol::TypeApplication(constructor:, args:)
            constructor_symbol = registry.lookup(constructor)

            if constructor_symbol.type_params.size != args.size
              [Error::TypeArgsMismatch.new(
                  nil,
                  symbol.span,
                  type_name: constructor.name,
                  expected: constructor_symbol.type_params.size,
                  actual: args.size
              )]
            else
              []
            end + args.flat_map { validate_type_symbol(it, registry) }

          in Symbol::FunctionType(params:, return_type:)
            validate_type_symbol(return_type, registry) +
              params.flat_map { validate_type_symbol(it, registry) }

          in Symbol::Function(params:, return_type:)
            validate_type_symbol(return_type, registry) +
              params.values.flat_map { validate_type_symbol(it, registry) }

          in Symbol::RecordType
            []
          end
        end
      end
    end
  end
end
