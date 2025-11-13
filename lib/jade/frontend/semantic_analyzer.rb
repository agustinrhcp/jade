module Jade
  module Frontend
    module SemanticAnalyzer
      extend self

      def analyze(ast, registry)
        analyze_r(ast, registry, Scope.new)
          .to_result
          .map { [ast, registry] }
      end

      private

      def analyze_r(ast, registry, scope)
        case ast
        in AST::Literal
          Result[scope, []]

        in AST::VariableBinding(name:, expression:)
          analyze_r(expression, registry, scope) => { errors: expr_errors }

          if scope.lookup(name)
            Result[scope, [ShadowingError.new(name)] + expr_errors]

          else
            Result[scope.bind(name, Symbol.var(name)), expr_errors]
          end

        in AST::VariableReference(name:)
          if scope.lookup(name)
            Result[scope, []]
          else
            UndefinedVariable.new(name)
              .then { Result[scope, [it]] }
          end

        in AST::Body(expressions:)
          expressions
            .reduce(Result[scope, []]) do |acc, expression|
              analyze_r(expression, registry, acc.scope) => Result[expr_scope, expr_errors]
              Result[expr_scope, expr_errors + acc.errors]
            end
        end
      end

      Result = Data.define(:scope, :errors) do
        def to_result
          return Err[errors] if errors.any?

          Ok[nil]
        end
      end

      Scope = Data.define(:bindings) do
        def initialize(bindings: {})
          super
        end

        def bind(name, symbol)
          with(bindings: bindings.merge(name => symbol))
        end

        def lookup(binding)
          bindings[binding]
        end
      end

      class Error; end
      class ShadowingError < Error
        def initialize(name)
          super()
          @name = name
        end

        def message
          "Variable #{@name} shadows existing variable"
        end
      end

      class UndefinedVariable < Error
        def initialize(var_ref)
          super()
          @var_ref = var_ref
        end

        def message
          "Undefined variable #{@var_ref.name}"
        end
      end
    end
  end
end
