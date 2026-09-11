module Jade
  module Frontend
    module TypeChecking
      module Error
        class NarrowedSignature < Jade::Error
          def initialize(entry, span, function_name:, var:, found:)
            @function_name = function_name
            @var = var
            @found = found
            super(entry:, span:)
          end

          def message
            case @found
            in Type::Var
              "`#{@function_name}` says `#{@var}` and `#{@found}` can be different " \
                'types, but its body needs them to be the same'
            else
              "`#{@function_name}` says it works for any `#{@var}`, but its body only " \
                "works when `#{@var}` is #{shown}"
            end
          end

          def label
            'narrower than its signature'
          end

          def notes
            [Jade::Diagnostics::Annotation[
              :help,
              'write the type the body needs in the signature, or make the body ' \
                'work for any type',
            ]]
          end

          private

          def shown
            kept, renamed = @found
              .unbound_vars
              .uniq(&:id)
              .partition { it.name && it.name != @var }

            renamed
              .zip(('a'..'z').to_a - [@var, *kept.map(&:name)])
              .to_h { |(var, letter)| [var.id, Type.var(var.id, letter)] }
              .then { Substitution[it].apply(@found).to_s }
          end
        end
      end
    end
  end
end
