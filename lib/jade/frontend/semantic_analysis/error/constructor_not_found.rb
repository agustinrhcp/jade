module Jade
  module Frontend
    module SemanticAnalysis
      module Error
        class ConstructorNotFound < Jade::Error
          attr_reader :candidates

          def initialize(entry, span, name:, exposed_type_module: nil, candidates: [])
            @name = name
            @exposed_type_module = exposed_type_module
            @candidates = candidates
            super(entry:, span:)
          end

          def message
            base = "I cannot find a `#{@name}` constructor"
            return base unless @exposed_type_module

            "#{base}. The type `#{@name}` is exposed by `#{@exposed_type_module}` but its " \
              "constructor is private — add `#{@name}(..)` to that module's `exposing` list."
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
