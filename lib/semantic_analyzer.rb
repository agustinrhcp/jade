require 'ast'

module SemanticAnalyzer
  extend self

  def analyze(node, scope = Scope.new) 
    case node
    in AST::Literal
      [node, []]

    in AST::Variable(name:)
      if scope.resolve(:name)
        [node, []]
      else
        [node, [Error.new("Undefined variable '#{name}'", range: node.range)]]
      end

    in AST::Unary(operator:, right:)
      analyzed_right, errors = analyze(right, scope)
      [node.with(right: analyzed_right), errors]

    in AST::Binary(left:, right:)
      analyzed_left, errors_left = analyze(left, scope)
      analyzed_right, errors_right = analyze(right, scope)
      [node.with(right: analyzed_right, left: analyzed_left), errors_left + errors_right]

    in AST::Grouping(expression:)
      analyzed_expression, errors = analyze(expression, scope)
      [node.with(expression: analyzed_expression), errors]

    in AST::VariableDeclaration(name:, expression:)
      analyzed_expression, errors = analyze(expression, scope)
      scope.define(name, expression.range)
      [node.with(expression: analyzed_expression), errors]

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
