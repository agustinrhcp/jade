module Jade
  module Frontend
    module TypeChecking
      module Error
        class IfBranchTypeMismatch < TypeMismatch
          def initialize(entry, span, expected:, actual:, branch:)
            super
            @branch = branch == :then ? 'then' : 'else'
          end

          def message
            "The #{@branch} branch of this if statement is expected to return" +
              " #{@expected} but got #{@actual}"
          end
        end
      end
    end
  end
end
