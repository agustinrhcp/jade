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
      new_context = context.annotate_fn(name, fn_type)

      fn_context = annotated_parameters
        .reduce(new_context) do |acc, param|
          acc.annotate_var(param.name, param.type)
        end

      Helpers.check_many(body, fn_context)
        .and_then do |(typed_body, _)|
          if typed_body.last.type != resolved_return_type
            return Err[[
              Error.new("Expected return type #{resolved_return_type}, got #{typed_body.last}", range: body.last.range)
            ]]
          end

          Ok[[
            node.annotate(fn_type)
              .with(return_type: resolved_return_type)
              .with(parameters: annotated_parameters), new_context
          ]]
        end
    end
  end
end
