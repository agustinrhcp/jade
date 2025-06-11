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

    in AST::RecordDeclaration(name:, fields:)
      if scope.resolve_record(name)
        return [node, scope, [Error.new("Already defined record type '#{name}'", range: node.range)]]
      end

      unless fields.uniq { |f| f.name }.length == fields.length
        indexed_fields = fields.group_by(&:name)
        errors = fields
          .map(&:name)
          .tally.select { |f, c| c > 1 }
          .map { |f, _| Error.new("Duplicate field '#{f}' in record '#{name}'", range: indexed_fields[f].last.range) }

        return [node, scope, errors]
      end

      [node, scope.define_unbound_record(name, fields), []]

    in AST::RecordInstantiation(name:, fields:)
      record_type = scope.resolve_record(name)

      unless record_type
        return [node, scope, [Error.new("Undefined record type '#{name}'", range: node.range)]]
      end

      unless fields.uniq { |f| f.name }.length == fields.length
        indexed_fields = fields.group_by(&:name)
        errors = fields
          .map(&:name)
          .tally.select { |f, c| c > 1 }
          .map { |f, _| Error.new("Duplicate assignment to field '#{f}' in record instantiation", range: indexed_fields[f].last.range) }

        return [node, scope, errors]
      end

      expected_field_names = record_type.fields
      given_field_names = fields.map(&:name)

      missing = expected_field_names - given_field_names
      extra   = given_field_names - expected_field_names

      missing_or_extra_fields_errors = missing
        .map { |field_name| Error.new("Missing required field '#{field_name}' for record '#{name}'", range: node.range)}
        .concat(extra.map { |field_name| Error.new("Unknown field '#{field_name}' for record '#{name}'", range: node.range)})

      analayzed_fields, _, field_errors = analyze_many(scope, fields)
      [
        node.with(fields: analayzed_fields),
        scope,
        missing_or_extra_fields_errors.concat(field_errors),
      ]

    in AST::RecordFieldAssign(name:, expression:)
      analyzed_expression, _, expression_errors = analyze(expression, scope)
      [node.with(expression: analyzed_expression), scope, expression_errors]

    in AST::AnonymousRecord(fields:)
      analyzed_fields, _, field_errors = analyze_many(scope, fields)

      unless fields.uniq { |f| f.name }.length == fields.length
        indexed_fields = fields.group_by(&:name)
        errors = fields
          .map(&:name)
          .tally.select { |f, c| c > 1 }
          .map { |f, _| Error.new("Duplicate field '#{f}' in anonymous record", range: indexed_fields[f].last.range) }

        return [node, scope, errors]
      end

      [node.with(fields: analyzed_fields), scope, field_errors]

    in AST::Module(name:, exposing:, statements:, range:)
      # TODO: Register module
      analyzed_statements, new_scope, stmts_errors = analyze_many(scope, statements)

      missing_exposed_errors = exposing
        .reject { |exposed| new_scope.resolve(exposed) }
        .map { |exposed| Error.new("Cannot find a #{exposed} value to expose", range:)}

      [node.with(statements: analyzed_statements), new_scope, stmts_errors + missing_exposed_errors]
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
