module Jade
  module Frontend
    module SemanticAnalysis
      module Error
        class ConstantNotCallable < Jade::Error
          def initialize(entry, span, name:)
            @name = name
            super(entry:, span:)
          end

          attr_reader :name

          def message
            "`#{name}` is a value, not a function — write `#{name}`, not `#{name}()`"
          end

          def label
            "not callable"
          end
        end
      end
    end
  end
end
