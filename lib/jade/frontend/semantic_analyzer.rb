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

          bind(scope, name, Symbol.var(name))
            .add_errors(expr_errors)

        in AST::VariableReference(name:)
          lookup(scope, name)

        in AST::Body(expressions:)
          expressions
            .reduce(Result[scope, []]) do |acc, expression|
              analyze_r(expression, registry, acc.scope) => Result[expr_scope, expr_errors]
              Result[expr_scope, expr_errors + acc.errors]
            end

        in AST::FunctionDeclaration(params:, body:)
          params
            .reduce(Result[scope, []]) do |acc, param|
              bind(acc.scope, param.name, Symbol.param(param.name))
                .add_errors(acc.errors)
            end
            .then do
              analyze_r(body, registry, it.scope)
                .add_errors(it.errors)
            end
        end
      end

      private

      def bind(scope, name, symbol)
        if scope.lookup(name)
          Result[scope, [ShadowingError.new(name)]]

        else
          Result[scope.bind(name, symbol), []]
        end
      end

      def lookup(scope, name)
        if scope.lookup(name)
          Result[scope, []]
        else
          UndefinedVariable.new(name)
            .then { Result[scope, [it]] }
        end
      end

      Result = Data.define(:scope, :errors) do
        def to_result
          return Err[errors] if errors.any?

          Ok[nil]
        end

        def add_errors(more_errors)
          with(errors: errors + more_errors)
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
