module TypeChecker
  module Substitution
    extend self

    def substitute(type, context)
      case type
      in Type::Int | Type::String | Type::Bool
        type

      in Type::Generic(name:)
        type.with(substituted: context.resolve_substitution(name))

      in Type::Record(fields:, params:)
        type
          .with(
            params: type.params.reduce({}) do |acc, param|
              acc.merge(param => context.resolve_substitution(param))
            end,
            fields: fields.transform_values { substitute(it, context) },
          )

      end
    end
  end
end
