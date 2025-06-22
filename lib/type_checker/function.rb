module TypeChecker
  module Function
    extend self

    def check_declaration(node, context)
      node => AST::FunctionDeclaration(
        name:,
        parameters:,
        return_type:,
        body:,
        range:
      )

      annotated_parameters = parameters
        .map { |param| param.annotate(context.resolve_type(param.type)) }

      resolved_return_type = context.resolve_type(return_type)

      if resolved_return_type.nil?
        return Err[[Error.new("Undefined type #{return_type}", range:)]]
      end

      fn_type = Type::Function.new(annotated_parameters.map(&:type), resolved_return_type)

      new_context = context
        .define_fn(name, parameters)
        .annotate_fn(name, fn_type)

      fn_context = annotated_parameters
        .reduce(new_context) do |acc, param|
          acc
            .define_var(param.name)
            .annotate_var(param.name, param.type)
        end

      Helpers.check_many(body, fn_context)
        .and_then do |(typed_body, _)|
          if typed_body.last.type != Substitution.substitute(resolved_return_type, context)
            return Err[[
              Error.new("Expected return type #{resolved_return_type}, got #{typed_body.last.type}", range: body.last.range)
            ]]
          end

          Ok[Tuple[
            node
              .annotate(fn_type)
              .with(return_type: resolved_return_type)
              .with(parameters: annotated_parameters),
            new_context,
          ]]
        end
    end
  end
end
