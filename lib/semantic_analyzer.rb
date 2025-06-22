require 'result'

require 'ast'
require 'context'
require 'tuple'

module SemanticAnalyzer
  extend self

  def analyze(node, context = Context.new) 
    case node
    in AST::Literal
      Ok[Tuple[node, context]]

    in AST::Variable(name:)
      if context.resolve_var(name)
        Ok[Tuple[node, context]]
      else
        Err[[Error.new("Undefined variable '#{name}'", range: node.range)]]
      end

    in AST::Unary(operator:, right:)
      analyze(right, context).map do |(analyzed_right, new_context)|
        Tuple[node.with(right: analyzed_right), new_context]
      end

    in AST::Binary(left:, right:)
      case [analyze(left, context), analyze(right, context)]
      in [Ok([analyzed_left, _]), Ok([analyzed_right, _])]
        node
          .with(
            right: analyzed_right,
            left: analyzed_left,
          )
          .then { Ok[Tuple[it, context]] }

      in [Ok, Err(errors)]
        Err[errors]

      in [Err(errors), Ok]
        Err[errors]

      in [Err(errors_left), Err(errors_right)]
        Err[errors_left + errors_right]
      end

    in AST::Grouping(expression:)
      analyze(expression, context)
        .and_then do |analyzed_expression|
          Tuple[node.with(expression: analyzed_expression), context]
        end

    in AST::VariableDeclaration(name:, expression:)
      if context.resolve_var(name)
        return Err[[Error.new("Already defined variable '#{name}'", range: node.range)]]
      end

      analyze(expression, context)
        .map do |(analyzed_expression, new_context)|
          Tuple[
            node.with(expression: analyzed_expression),
            new_context.define_var(name),
          ]
        end

    in AST::Program(statements:)
      analyze_many(statements, context)
        .map do |(analyzed_stmts, _)|
          Tuple[node.with(statements: analyzed_stmts), context]
        end

    in AST::FunctionDeclaration(name:, parameters:, return_type:, body:)
      if context.resolve_fn(name)
        return Err[[Error.new("Already defined function '#{name}'", range: node.range)]]
      end

      function_context = parameters
        .reduce(context) { |acc, param| acc.define_var(param.name) } 
        # Define the function for recursion
        .define_fn(name, parameters)

      analyze_many(body, function_context)
        .map do |(analyzed_body, _)|
          Tuple[node.with(body: analyzed_body), context.define_fn(name, parameters)]
        end

    in AST::FunctionCall(name:, arguments:)
      fn = context.resolve_fn(name)

      unless fn
        return Err[[Error.new("Undefined function '#{name}'", range: node.range)]]
      end

      unless fn.parameters.size == arguments.size
        return Err[[Error.new("Function '#{name}' expects #{fn.arity} arguments, got #{arguments.size}", range: node.range)]]
      end

      analyze_many(arguments, context)
        .map do |(analyzed_arguments, _)|
          Tuple[node.with(arguments: analyzed_arguments), context]
        end

    in AST::RecordDeclaration(name:, params:, fields:)
      if context.resolve_type(name)
        return Err[[Error.new("Already defined record type '#{name}'", range: node.range)]]
      end

      validate_uniquness_of_named_pairs(fields) do |f|
        "Duplicate field '#{f}' in record '#{name}'"
      end
        .then { return Err[it] if it.any? }

      fields
        .select { |f| f.type.is_a?(AST::GenericRef) }
        .reject { |f| params.include?(f.type.name) }
        .map    { |f| Error.new("Unbound type variable '#{f.type.name}' for '#{name}' definition", range: node.range) }
        .then { return Err[it] if it.any? }

      Tuple[node, context.define_type(name, node)]
        .then { Ok[it] }

    in AST::RecordInstantiation(name:, fields:)
      record_type = context.resolve_type(name)

      unless record_type
        return Err[[Error.new("Undefined record type '#{name}'", range: node.range)]]
      end

      validate_uniquness_of_named_pairs(fields) do |f|
        "Duplicate assignment to field '#{f}' in record instantiation"
      end
        .then { return Err[it] if it.any? }

      expected_field_names = record_type.fields.map(&:name)
      given_field_names = fields.map(&:name)

      missing = expected_field_names - given_field_names
      extra   = given_field_names - expected_field_names

      missing
        .map { |field_name| Error.new("Missing required field '#{field_name}' for record '#{name}'", range: node.range)}
        .concat(extra.map { |field_name| Error.new("Unknown field '#{field_name}' for record '#{name}'", range: node.range)})
        .then { return Err[it] if it.any? }

      analyze_many(fields, context)
        .map do |(analyzed_fields, _)|
          Tuple[node.with(fields: analyzed_fields), context]
        end

    in AST::RecordFieldAssign(name:, expression:)
      analyze(expression, context)
        .map { Tuple[node.with(expression: it.first), context] }

    in AST::AnonymousRecord(fields:)
      validate_uniquness_of_named_pairs(fields) do |f|
        "Duplicate field '#{f}' in anonymous record"
      end
        .then { return Err[it] if it.any? }

      analyze_many(fields, context)
        .map do |(analyzed_fields, _)|
          Tuple[node.with(fields: analyzed_fields), context]
        end

    in AST::RecordAccess(target:)
      analyze(target, context)
        .map do |(analyzed_target, new_context)|
          Tuple[node.with(target: analyzed_target), new_context]
        end

    in AST::Module(name:, exposing:, statements:, range:)
      # TODO: Register module
      analyze_many(statements, context)
        .and_then do |(analyzed_statements, inner_module_context)|
          missing_exposed_errors = exposing
            # TODO: Know if it's a constant or an identifier
            .reject { |exposed| inner_module_context.resolve_fn(exposed) || inner_module_context.resolve_type(exposed) }
            .map { |exposed| Error.new("Cannot find a #{exposed} value to expose", range:) }
            .then { return it if it.any? }

          Tuple[node.with(statements: analyzed_statements), inner_module_context]
            .then { Ok[it] }
        end

    in AST::UnionType(name:, variants:)
      if context.resolve_type(name)
        return Err[[Error.new("Already defined type '#{name}'", range: node.range)]]
      end

      validate_uniquness_of_named_pairs(variants) do |v|
        "Duplicate variant '#{v}' type '#{name}'"
      end
        .then { return Err[it] if it.any? }

      analyze_many(variants, context)
        .map do |(analyzed_variants, _)|
          Tuple[node.with(variants: analyzed_variants), context.define_type(name, node)]
        end

    in AST::Variant(name:, fields:, params:)
      analyzed_variant, errors = case [fields, params]
        in [[], []]
          Ok[Tuple[node, context]]
        in [some_fields, []] if some_fields.any?
          validate_uniquness_of_named_pairs(some_fields) do |v|
            "Duplicate variant field '#{f}' for field'#{name}'"
          end
            .then { return Err[it] if it.any? }

          Ok[Tuple[node, context]]

        in [[], some_params] if some_params.any?
          Ok[Tuple[node, context]]
        end
    end
  end

  private

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

  def reduce_nodes(list, initial_context)
    list.reduce(Ok[Tuple[[], initial_context]]) do |acc, item|
      acc
        .on_err do |(errors, context)|
          yield(item, context)
            .map_error { |e| Tuple[errors + e, context] }
            .and_then { Err[_1] }
        end
        .and_then do |(collected, context)|
          yield(item, context)
            .map do |(checked, new_context)|
              Tuple[collected + [checked], new_context]
            end
            .map_error { |e| [e, context] }
        end
    end
      .map_error(&:first)
  end

  def analyze_many(nodes, context)
    reduce_nodes(nodes, context) do |node, next_context|
      analyze(node, next_context)
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
