module Jade
  module Frontend
    module TypeChecking
      module Error
        class UndeclaredRequirement < Jade::Error
          def initialize(entry, span, interface:, fn_name:, constraint:, declared:)
            super(entry:, span:)
            @interface  = interface
            @fn_name    = fn_name
            @constraint = constraint
            @declared   = declared
          end

          def message
            "Implementation of #{@interface}.#{@fn_name} requires #{@constraint}, " \
              "which #{@interface} does not declare. It declares #{@declared}"
          end

          def label
            "requires #{@constraint}"
          end

          def notes
            [
              Jade::Diagnostics::Annotation[
                :help,
                "add it to the method: `#{@fn_name} : ... with #{@constraint}`",
              ],
            ]
          end
        end
      end
    end
  end
end
