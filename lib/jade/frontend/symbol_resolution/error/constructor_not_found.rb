module Jade
  module Frontend
    module SymbolResolution
      module Error
        class ConstructorNotFound < Jade::Error
          def initialize(entry, span, name:, exposed_type_module: nil)
            @name = name
            @exposed_type_module = exposed_type_module
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
        end
      end
    end
  end
end
