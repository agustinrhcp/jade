module Jade
  module Frontend
    module SemanticAnalysis
      module Error
        class TopLevelStatement < Jade::Error
          def initialize(entry, span)
            super(entry:, span:)
          end

          def message
            "Only declarations can appear at the top level of a module"
          end

          def label
            'not a declaration'
          end

          def notes
            [Jade::Diagnostics::Annotation[
              :help,
              'a value belongs in a zero-argument `def`, like `def limit -> Int`',
            ]]
          end
        end
      end
    end
  end
end
