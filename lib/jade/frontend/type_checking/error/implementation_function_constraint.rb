module Jade
  module Frontend
    module TypeChecking
      module Error
        class ImplementationFunctionConstraint < Jade::Error
          def initialize(entry, span, interface:, fn_name:, constraint:)
            super(entry:, span:)
            @interface  = interface
            @fn_name    = fn_name
            @constraint = constraint
          end

          def message
            "Implementation of #{@interface}.#{@fn_name} requires #{@constraint}, " \
              'whose type is not the one being implemented. An implementation ' \
              'can only require interfaces of the type it implements'
          end

          def label
            "requires #{@constraint}"
          end

          def notes
            [
              Jade::Diagnostics::Annotation[
                :help,
                'give the function a concrete type for that parameter, or move ' \
                  'the requirement onto the type being implemented',
              ],
            ]
          end
        end
      end
    end
  end
end
