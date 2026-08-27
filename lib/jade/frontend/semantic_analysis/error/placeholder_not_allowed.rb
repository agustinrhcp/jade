module Jade
  module Frontend
    module SemanticAnalysis
      module Error
        # `Rect(w: _, h: 2)` where `Rect` is `Rect(Int, Int)`: positional, so
        # `w:` names nothing. A variant carrying a record takes the hole.
        class PlaceholderNotAllowed < Jade::Error
          def initialize(entry, span, field:, name:)
            @field = field
            @name = name
            super(entry:, span:)
          end

          def message
            "`#{@name}` is a union variant; its arguments are positional " \
              "and have no names, so `#{@field}:` has nothing to refer to"
          end

          def label
            'not allowed here'
          end

          def notes
            [Jade::Diagnostics::Annotation[
              :help,
              "write `#{@name}(_, x)` positionally, or pipe into the " \
                "first argument with `|> #{@name}(x)`",
            ]]
          end
        end
      end
    end
  end
end
