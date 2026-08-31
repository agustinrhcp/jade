module Jade
  module Frontend
    module ForwardDeclaration
      module Error
        # A struct and a union's variant both define a constructor, and a
        # constructor is named without its type, so one module holds at most
        # one of a name.
        class DuplicateConstructorName < Jade::Error
          def initialize(entry, span, name, declaring:, type:, owner:, first_span: nil)
            @name = name
            @declaring = declaring
            @type = type
            @owner = owner
            @first_span = first_span
            super(entry:, span:)
          end

          def message
            case @owner
            in Symbol::Struct then "`#{@name}` is already a struct in this module"
            in Symbol::Union then "`#{@name}` is already a constructor of `#{@owner.name}`"
            end
          end

          def label
            case @declaring
            in :variant then "`#{@type}` cannot also declare `#{@name}`"
            in :struct then "cannot declare a struct `#{@name}`"
            end
          end

          def secondary
            return [] unless @first_span

            [[@first_span, 'first declared here']]
          end

          def notes
            [Jade::Diagnostics::Annotation[:help, 'rename one of them']]
          end
        end
      end
    end
  end
end
