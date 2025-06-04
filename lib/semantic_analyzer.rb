require 'ast'
require 'scope'

module SemanticAnalyzer
  extend self

  def analyze(node, scope = Scope.new) 
    case node
    in AST::Literal
      [node, scope, []]

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
      if scope.resolve(name)
        [node, scope, [Error.new("Already defined variable '#{name}'", range: node.range)]]
      else
        analyzed_expression, current_scope, errors = analyze(expression, scope)
        [
          node.with(expression: analyzed_expression),
          current_scope.define_unbound_var(name, expression.range),
          errors,
        ]
      end

    in AST::Program(statements:)
      analyze_many(scope, statements)
      .then { |analyzed_stmts, new_scope, errors| [node.with(statements: analyzed_stmts), new_scope, errors] }

    in AST::FunctionDeclaration(name:, parameters:, return_type:, body:)
      function_scope = parameters.parameters.reduce(scope) do |acc, param|
        acc.define_typed_var(param.name, param.type, param.range)
      end

      analyzed_body, _, body_errors = analyze_many(function_scope, body)

      [node.with(body: analyzed_body), scope.define_unbound_function(name, parameters.size, node.range), body_errors]

    in AST::FunctionCall(name:, arguments:)
      if fn = scope.resolve(name)
        if fn.arity == arguments.size
          analyzed_arguments, _, argument_errors = analyze_many(scope, arguments)
          [node.with(arguments: analyzed_arguments), scope, argument_errors]
        else
          [
            node,
            scope,
            [Error.new("Function '#{name}' expects #{fn.arity} arguments, got #{arguments.size}", range: node.range)],
          ]
        end
      else
        [node, scope, [Error.new("Undefined function '#{name}'", range: node.range)]]
      end
    end
  end

  private

  def analyze_many(scope, statements)
    statements
      .reduce([[], scope, []]) do |(analyzed_stmts, current_scope, errors), stmt|
        analyzed_stmt, new_scope, stmt_errors = analyze(stmt, current_scope)
        [analyzed_stmts.concat([analyzed_stmt]), new_scope, errors.concat(stmt_errors)]
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
