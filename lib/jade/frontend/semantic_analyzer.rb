module Jade
  module Frontend
    module SemanticAnalyzer
      extend self

      def analyze_entry(entry, registry)
        analyze(entry.ast, registry)
          .map { entry }
      end

      def analyze(ast, registry)
        analyze_r(ast, registry, Scope.new)
          .to_result
          .map { [ast, registry] }
      end

      def analyze_repl(ast, registry, scope = Scope.new)
        analyze_r(ast, registry, scope)
          .to_result
      end

      private

      def analyze_r(ast, registry, scope)
        case ast
        in AST::Module(body:)
          # TODO: [SemanticAnalysis::Exposed]
          analyze_r(body, registry, scope)

        in AST::ImportDeclaration
          Result[scope, []]

        in AST::Literal
          Result[scope, []]

        in AST::VariableBinding(name:, expression:)
          analyze_r(expression, registry, scope) => { errors: expr_errors }

          bind(scope, name, Symbol.var(name))
            .add_errors(expr_errors)

        in AST::VariableReference(name:)
          lookup(scope, name)

        in AST::ConstructorReference(name:)
          lookup(scope, name)

        in AST::Body(expressions:)
          expressions
            .reduce(Result[scope, []]) do |acc, expression|
              analyze_r(expression, registry, acc.scope) => Result[expr_scope, expr_errors]
              Result[expr_scope, expr_errors + acc.errors]
            end

        in AST::FunctionDeclaration(name:, params:, body:, symbol:)
          params
            .reduce(Result[scope, []]) do |acc, param|
              bind(acc.scope, param.name, Symbol.param(param.name))
                .add_errors(acc.errors)
            end
            .then do
              analyze_r(body, registry, it.scope)
                .add_errors(it.errors)
            end
            .with(scope: scope.bind(name, symbol))

        in AST::InfixApplication(left:, right:)
          analyze_r(left, registry, scope) => { errors: l_errors }
          analyze_r(right, registry, scope) => { errors: r_errors }

          Result[scope, l_errors + r_errors]

        in AST::FunctionCall(callee:, args:)
          # TODO: Shameless copy paste from body
          args
            .reduce(Result[scope, []]) do |acc, arg|
              analyze_r(arg, registry, acc.scope) => Result[arg_scope, arg_errors]
              Result[arg_scope, arg_errors + acc.errors]
            end => { errors: args_errors, scope: args_scope }

          analyze_r(callee, registry, args_scope)
            .add_errors(args_errors)

        in AST::TypeDeclaration(name:, symbol:, variants:)
          variants
            .reduce(bind(scope, name, symbol)) do |acc, variant|
              bind(acc.scope, variant.name, symbol)
                .add_errors(acc.errors)
            end

        in AST::IfThenElse(condition:, if_branch:, else_branch:)
          analyze_r(condition, registry, scope) => { errors: condition_errors }
          analyze_r(if_branch, registry, scope) => { errors: if_errors }
          analyze_r(else_branch, registry, scope) => { errors: else_errors }

          Result[scope, condition_errors + if_errors + else_errors]

        in AST::MemberAccess
          Result[scope, []]
        end
      end

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

          Ok[scope]
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
          "Undefined variable #{@var_ref}"
        end
      end
    end
  end
end
