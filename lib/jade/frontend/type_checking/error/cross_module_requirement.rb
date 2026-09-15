module Jade
  module Frontend
    module TypeChecking
      module Error
        class CrossModuleRequirement < Jade::Error
          def initialize(entry, span, interface:, fn_name:, constraint:)
            super(entry:, span:)
            @interface  = interface
            @fn_name    = fn_name
            @constraint = constraint
          end

          def message
            "Implementation of #{@interface}.#{@fn_name} requires #{@constraint}, " \
              "but #{@interface} is declared in another module. A requirement " \
              'can only be added to an interface this module declares'
          end

          def label
            "requires #{@constraint}"
          end

          def notes
            [
              Jade::Diagnostics::Annotation[
                :help,
                'give the function a concrete type for that parameter, or move ' \
                  'the implementation into the module that declares the interface',
              ],
            ]
          end
        end
      end
    end
  end
end
