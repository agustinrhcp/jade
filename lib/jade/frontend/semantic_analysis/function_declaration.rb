module Jade
  module Frontend
    module SemanticAnalysis
      module FunctionDeclaration
        extend self
        extend Helper

        def analyze(node, registry, scope)
          node => AST::FunctionDeclaration(name:, params:, body:, symbol:, return_type:)

          annotation_errors = analyze_return_type(return_type, registry) + analyze_params(params, registry)

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

        def analyze_return_type(type, registry)
          validate_type_symbol(type, registry)
        end

        def analyze_params(params, registry)
          params.flat_map { validate_type_symbol(it.type, registry) }
        end

        def validate_type_symbol(node, registry, symbol = node.symbol)
          case symbol
          in Symbol::Variable
            []

          in Symbol::TypeApplication(constructor:, args:)
            constructor_symbol = registry.lookup(constructor)

            if constructor_symbol.type_params.size != args.size
              [Error::TypeArgsMismatch.new(
                  nil,
                  node.range,
                  type_name: constructor.name,
                  expected: constructor_symbol.type_params.size,
                  actual: args.size
              )]
            else
              []
            end + args.flat_map { validate_type_symbol(node, registry, it) }

          in Symbol::FunctionType(params:, return_type:)
            validate_type_symbol(node, registry, return_type) +
              params.flat_map { validate_type_symbol(node, registry, it) }

          in Symbol::RecordType
            []
          end
        end
      end
    end
  end
end
