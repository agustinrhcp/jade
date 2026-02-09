module Jade
  module Frontend
    module SemanticAnalysis
      module Helper
        def analyze_node(node, registry, scope)
          SemanticAnalyzer.send(:analyze_r, node, registry, scope)
        end

        def bind(scope, name, symbol)
          if scope.lookup(name)
            SemanticAnalyzer::Result[scope, [ShadowingError.new(name)]]

          else
            SemanticAnalyzer::Result[scope.bind(name, symbol), []]
          end
        end

        def lookup(scope, name)
          if scope.lookup(name)
            SemanticAnalyzer::Result[scope, []]
          else
            UndefinedVariable.new(name)
              .then { Result[scope, [it]] }
          end
        end

        def validate_type_symbol(symbol, registry)
          case symbol
          in Symbol::Union(variants:)
            variants.flat_map { validate_type_symbol(it, registry) }

          in Symbol::Variant(args:)
            args.flat_map { validate_type_symbol(it, registry) }

          in Symbol::TypeRef
            registry.lookup(symbol)
              .then { validate_type_symbol(it, registry) }

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

          in Symbol::RecordType(fields:)
            fields.reduce([]) do |acc, (k, v)|
              acc + validate_type_symbol(v, registry)
            end
          end
        end
      end
    end
  end
end
