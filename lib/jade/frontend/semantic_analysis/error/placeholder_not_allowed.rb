module Jade
  module Frontend
    module SemanticAnalysis
      module Error
        # Two different situations reach here, and the reader is holding
        # exactly one of them: a variant whose arguments have no names at
        # all, or a keyed variant whose names exist but whose record
        # literal has no hole to put a placeholder in.
        class PlaceholderNotAllowed < Jade::Error
          def initialize(entry, span, field:, name:, keyed:)
            @field = field
            @name = name
            @keyed = keyed
            super(entry:, span:)
          end

          def message
            return keyed_message if @keyed

            "`#{@name}` is a union variant; its arguments are positional " \
              "and have no names, so `#{@field}:` has nothing to refer to"
          end

          def label
            'not allowed here'
          end

          def notes
            [Jade::Diagnostics::Annotation[:help, @keyed ? keyed_help : positional_help]]
          end

          private

          def keyed_message
            "`#{@name}` carries a record, and a record literal has no " \
              "placeholder — `#{@field}: _` cannot be a hole"
          end

          def positional_help
            "pass them positionally — `#{@name}(_, x)` — or pipe into the " \
              "first argument, which `|>` fills in for you: `|> #{@name}(x)`"
          end

          def keyed_help
            "write the lambda instead: `(v) -> { #{@name}(#{@field}: v, ...) }`"
          end
        end
      end
    end
  end
end
