module Jade
  module Frontend
    module TypeChecking
      module Error
        class NarrowedMethodVariable < Jade::Error
          def initialize(entry, span, interface:, fn_name:, var_name:, bound_to:)
            super(entry:, span:)
            @interface = interface
            @fn_name   = fn_name
            @var_name  = var_name
            @bound_to  = bound_to
          end

          def message
            "Implementation of #{@interface}.#{@fn_name} fixes `#{@var_name}` to " \
              "#{@bound_to}, which #{@fn_name} leaves to the call site"
          end

          def label
            "fixes `#{@var_name}`"
          end

          def notes
            [
              Jade::Diagnostics::Annotation[
                :help,
                "the implementation has to work for every `#{@var_name}` the " \
                  'method is written for, not one of them',
              ],
            ]
          end
        end
      end
    end
  end
end
