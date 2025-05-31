require 'ast'

module SemanticAnalyzer
  extend self

  def analyze(node, scope = Scope.new) 
    case node
    in AST::Literal
      [node, []]

    in AST::Variable(name:)
      if scope.resolve(name)
        [node, scope, []]
      else
        [node, scope, [Error.new("Undefined variable '#{name}'", range: node.range)]]
      end

    in AST::Unary(operator:, right:)
      analyzed_right, _, errors = analyze(right, scope)
      [node.with(right: analyzed_right), scope, errors]

    in AST::Binary(left:, right:)
      analyzed_left, _, errors_left = analyze(left, scope)
      analyzed_right, _, errors_right = analyze(right, scope)
      [node.with(right: analyzed_right, left: analyzed_left), scope, errors_left + errors_right]

    in AST::Grouping(expression:)
      analyzed_expression, _, errors = analyze(expression, scope)
      [node.with(expression: analyzed_expression), scope, errors]

    in AST::VariableDeclaration(name:, expression:)
      analyzed_expression, current_scope, errors = analyze(expression, scope)
      scope.define(name, expression.range)
      [node.with(expression: analyzed_expression), current_scope, errors]

    in AST::Program(statements:)
      statements
        .reduce([[], scope, []]) do |(analyzed_stmts, current_scope, errors), stmt|
          analyzed_stmt, new_scope, stmt_errors = analyze(stmt, current_scope)
          [nodes.concat([analyzed_stmt]), new_scope, errors.concat(stmt_errors)]
        end
        .then { |analyzed_stmts, errors| [node.with(statements: analyzed_stmts), errors] }
    end
  end

  Scope = Data.define(:vars) do
    def initialize(vars: {})
      super
    end

    def define(name, range)
      with(vars: vars.merge(name: range))
    end

    def resolve(name)
      vars[name]
    end
  end

  class Error < StandardError
    attr_reader :range

    def initialize(message, range:)
      @range = range
      super(message)
    end
  end
end
