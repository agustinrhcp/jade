module Jade
  module Frontend
    module SemanticAnalysis
      module Error
        class NonPortBackground < Jade::Error
          def message
            'Backgrounding a task needs a port call. A composed task carries ' \
              'a function, which cannot be sent to a worker.'
          end

          def label
            'not a port call'
          end
        end
      end
    end
  end
end
