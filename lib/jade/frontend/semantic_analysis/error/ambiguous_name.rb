module Jade
  module Frontend
    module SemanticAnalysis
      module Error
        class AmbiguousName < Jade::Error
          def initialize(entry, span, name:, modules:)
            @name = name
            @modules = modules
            super(entry:, span:)
          end

          def message
            "`#{@name}` is imported from both #{sentence(@modules)}"
          end

          def label
            'ambiguous'
          end

          def notes
            [Jade::Diagnostics::Annotation[
              :help,
              "qualify it, as in `#{@modules.first}.#{@name}`, or drop it from all but one import",
            ]]
          end

          private

          def sentence(names)
            "#{names[0...-1].join(', ')} and #{names.last}"
          end
        end
      end
    end
  end
end
