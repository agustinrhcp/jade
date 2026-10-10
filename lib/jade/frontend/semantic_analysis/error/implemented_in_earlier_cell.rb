module Jade
  module Frontend
    module SemanticAnalysis
      module Error
        class ImplementedInEarlierCell < Jade::Error
          def initialize(entry, span, interface:, type:, cell:)
            @interface = interface
            @type = type
            @cell = cell
            super(entry:, span:)
          end

          def message
            "#{@interface} is already implemented for #{@type}, in #{@cell}"
          end

          def label
            'already implemented'
          end

          def notes
            [Jade::Diagnostics::Annotation[
              :help,
              "redefine `#{@type.split('.').last}` to implement it afresh",
            ]]
          end
        end
      end
    end
  end
end
