module Jade
  module Frontend
    module SemanticAnalysis
      module Error
        # `Rect(w: _, h: 2)`, where `Rect` is either of:
        #
        #   Rect(Int, Int)             positional, so `w:` names nothing
        #   Rect({ w: Int, h: Int })   named, but a record literal has no hole
        class PlaceholderNotAllowed < Jade::Error
          def initialize(entry, span, field:, name:, keyed:)
            @field = field
            @name = name
            @keyed = keyed
            super(entry:, span:)
          end

          def message
            if @keyed
              "`#{@name}` carries a record, and a record literal has no " \
                "placeholder, so `#{@field}: _` cannot be a hole"
            else
              "`#{@name}` is a union variant; its arguments are positional " \
                "and have no names, so `#{@field}:` has nothing to refer to"
            end
          end

          def label
            'not allowed here'
          end

          def notes
            if @keyed
              help("write the lambda instead: `(v) -> { #{@name}(#{@field}: v, ...) }`")
            else
              help("write `#{@name}(_, x)` positionally, or pipe into the " \
                   "first argument with `|> #{@name}(x)`")
            end
          end

          private

          def help(text)
            [Jade::Diagnostics::Annotation[:help, text]]
          end
        end
      end
    end
  end
end
