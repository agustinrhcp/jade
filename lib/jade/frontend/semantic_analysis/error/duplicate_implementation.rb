module Jade
  module Frontend
    module SemanticAnalysis
      module Error
        class DuplicateImplementation < Jade::Error
          def initialize(entry, span, interface:, type:, first_span:, parameterized:)
            @interface = interface
            @type = type
            @first_span = first_span
            @parameterized = parameterized
            super(entry:, span:)
          end

          def message
            "Duplicate implementation of #{@interface} for #{@type}"
          end

          def label
            "already implemented"
          end

          def secondary
            [[@first_span, 'first implemented here']]
          end

          def notes
            return [] unless @parameterized

            [Jade::Diagnostics::Annotation[
              :note,
              "an implementation is chosen by the head type `#{@type}` alone — " \
                'its type arguments do not select between implementations',
            ]]
          end
        end
      end
    end
  end
end
