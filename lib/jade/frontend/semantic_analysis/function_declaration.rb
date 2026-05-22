module Jade
  module Frontend
    module SemanticAnalysis
      module FunctionDeclaration
        extend self
        extend Helper

        def analyze(node, registry, scope, entry)
          node => AST::FunctionDeclaration(name:, body:, params:, return_type:, symbol:)

          annotation_errors = validate_type_symbol(symbol, registry, entry) +
            validate_predicate_return(name, return_type, symbol, registry, entry) +
            params.flat_map { validate_no_predicate_param(it, entry) }

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

        # `?` suffix is reserved for function declaration names. Forbid
        # it on parameters so `def f(empty?: Bool) -> Bool` doesn't bind
        # `empty?` as a value.
        def validate_no_predicate_param(param, entry)
          return [] unless param.name.end_with?('?')

          [Error::PredicateNameNotAllowed.new(entry.name, param.range, name: param.name)]
        end

        # `?`-suffixed function names must declare a `Bool` return type.
        # Catches `def empty? -> Int` at semantic analysis.
        def validate_predicate_return(name, return_type_ast, symbol, registry, entry)
          return [] unless name.end_with?('?')

          case registry.lookup(symbol).return_type
          in Symbol::TypeRef['Basics', 'Bool'] |
             Symbol::TypeApplication(constructor: Symbol::TypeRef['Basics', 'Bool'], args: [])
            []
          else
            [Error::PredicateMustReturnBool.new(
              entry.name,
              return_type_ast.range,
              fn_name: name,
            )]
          end
        end
      end
    end
  end
end
