require 'ast'
require 'context'

module SemanticAnalyzer
  extend self

  def analyze(node, context = Context.new) 
    case node
    in AST::Literal
      [node, context, []]

    in AST::Variable(name:)
      if context.resolve_var(name)
        [node, context, []]
      else
        [
          node,
          context,
          [Error.new("Undefined variable '#{name}'", range: node.range)],
        ]
      end

    in AST::Unary(operator:, right:)
      analyzed_right, _, errors = analyze(right, context)
      [node.with(right: analyzed_right), context, errors]

    in AST::Binary(left:, right:)
      analyzed_left, _, errors_left = analyze(left, context)
      analyzed_right, _, errors_right = analyze(right, context)
      [node.with(right: analyzed_right, left: analyzed_left), context, errors_left + errors_right]

    in AST::Grouping(expression:)
      analyzed_expression, _, errors = analyze(expression, context)
      [node.with(expression: analyzed_expression), context, errors]

    in AST::VariableDeclaration(name:, expression:)
      if context.resolve_var(name)
        [node, context, [Error.new("Already defined variable '#{name}'", range: node.range)]]
      else
        analyzed_expression, current_context, errors = analyze(expression, context)
        [
          node.with(expression: analyzed_expression),
          current_context.define_var(name, analyzed_expression),
          errors,
        ]
      end

    in AST::Program(statements:)
      analyze_many(context, statements)
      .then { |analyzed_stmts, new_context, errors| [node.with(statements: analyzed_stmts), new_context, errors] }

    in AST::FunctionDeclaration(name:, parameters:, return_type:, body:)
      function_context = parameters.parameters.reduce(context) do |acc, param|
        acc.define_var(param.name, param)
      end

      analyzed_body, _, body_errors = analyze_many(function_context, body)

      [node.with(body: analyzed_body), context.define_fn(name, node), body_errors]

    in AST::FunctionCall(name:, arguments:)
      if fn = context.resolve_fn(name)
        if fn.parameters.size == arguments.size
          analyzed_arguments, _, argument_errors = analyze_many(context, arguments)
          [node.with(arguments: analyzed_arguments), context, argument_errors]
        else
          [
            node,
            context,
            [Error.new("Function '#{name}' expects #{fn.arity} arguments, got #{arguments.size}", range: node.range)],
          ]
        end
      else
        [node, context, [Error.new("Undefined function '#{name}'", range: node.range)]]
      end

    in AST::RecordDeclaration(name:, fields:)
      if context.resolve_type(name)
        return [node, context, [Error.new("Already defined record type '#{name}'", range: node.range)]]
      end

      validate_uniquness_of_named_pairs(fields) do |f|
        "Duplicate field '#{f}' in record '#{name}'"
      end
        .then { return [node, context, it] if it.any? }

      [node, context.define_type(name, node), []]

    in AST::RecordInstantiation(name:, fields:)
      record_type = context.resolve_type(name)

      unless record_type
        return [node, context, [Error.new("Undefined record type '#{name}'", range: node.range)]]
      end

      validate_uniquness_of_named_pairs(fields) do |f|
        "Duplicate assignment to field '#{f}' in record instantiation"
      end
        .then { return [node, context, it] if it.any? }

      expected_field_names = record_type.fields.map(&:name)
      given_field_names = fields.map(&:name)

      missing = expected_field_names - given_field_names
      extra   = given_field_names - expected_field_names

      missing_or_extra_fields_errors = missing
        .map { |field_name| Error.new("Missing required field '#{field_name}' for record '#{name}'", range: node.range)}
        .concat(extra.map { |field_name| Error.new("Unknown field '#{field_name}' for record '#{name}'", range: node.range)})

      analayzed_fields, _, field_errors = analyze_many(context, fields)
      [
        node.with(fields: analayzed_fields),
        context,
        missing_or_extra_fields_errors.concat(field_errors),
      ]

    in AST::RecordFieldAssign(name:, expression:)
      analyzed_expression, _, expression_errors = analyze(expression, context)
      [node.with(expression: analyzed_expression), context, expression_errors]

    in AST::AnonymousRecord(fields:)
      analyzed_fields, _, field_errors = analyze_many(context, fields)

      validate_uniquness_of_named_pairs(fields) do |f|
        "Duplicate field '#{f}' in anonymous record"
      end
        .then { return [node, context, it] if it.any? }

      [node.with(fields: analyzed_fields), context, field_errors]

    in AST::RecordAccess(target:)
      analyzed_target, new_context, errors = analyze(target, context)
      [node.with(target: analyzed_target), new_context, errors]

    in AST::Module(name:, exposing:, statements:, range:)
      # TODO: Register module
      analyzed_statements, new_context, stmts_errors = analyze_many(context, statements)

      missing_exposed_errors = exposing
        # TODO: Know if it's a constant or an identifier
        .reject { |exposed| new_context.resolve_fn(exposed) || new_context.resolve_type(exposed) }
        .map { |exposed| Error.new("Cannot find a #{exposed} value to expose", range:)}

      [node.with(statements: analyzed_statements), new_context, stmts_errors + missing_exposed_errors]

    in AST::UnionType(name:, variants:)
      if context.resolve_type(name)
        return [node, context, [Error.new("Already defined type '#{name}'", range: node.range)]]
      end

      validate_uniquness_of_named_pairs(variants) do |v|
        "Duplicate variant '#{v}' type '#{name}'"
      end
        .then { return [node, context, it] if it.any? }

      analyzed_variants, new_context, variant_errors = analyze_many(context, variants)

      [
        node.with(variants: analyzed_variants),
        new_context.define_type(name, node.with(variants: analyzed_variants)),
        variant_errors,
      ]

    in AST::Variant(name:, fields:, params:)
      analyzed_variant, errors = case [fields, params]
        in [[], []]
          [node, []]
        in [some_fields, []] if some_fields.any?
          [node, validate_uniquness_of_named_pairs(some_fields) do |v|
            "Duplicate variant field '#{f}' for field'#{name}'"
          end]
        in [[], some_params] if some_params.any?
          [node, []]
        end

      [
        analyzed_variant,
        context,
        errors,
      ]
    end
  end

  private

  def analyze_many(context, statements)
    statements
      .reduce([[], context, []]) do |(analyzed_stmts, current_context, errors), stmt|
        analyzed_stmt, new_context, stmt_errors = analyze(stmt, current_context)
        [analyzed_stmts.concat([analyzed_stmt]), new_context, errors.concat(stmt_errors)]
      end
  end

  def validate_uniquness_of_named_pairs(named_pairs)
    return [] if named_pairs.uniq { |f| f.name }.length == named_pairs.length

    indexed_named_pairs = named_pairs.group_by(&:name)
    errors = named_pairs
      .map(&:name)
      .tally.select { |f, c| c > 1 }
      .map do |f, _|
        Error.new(yield(f), range: indexed_named_pairs[f].last.range)
      end

    errors
  end

  class Error < StandardError
    attr_reader :range

    def initialize(message, range:)
      @range = range
      super(message)
    end
  end
end
