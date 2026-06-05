module Jade
  module Frontend
    module ForwardDeclaration
      module Error
        class TypeNotFound < Jade::Error
          attr_reader :candidates

          def initialize(entry, span, name:, candidates: [])
            @name = name
            @candidates = candidates
            super(entry:, span:)
          end

          def message
            "Type `#{@name}` is not defined"
          end

          def label
            "not found"
          end

          def queried_name
            @name
          end
        end
      end
    end
  end
end
