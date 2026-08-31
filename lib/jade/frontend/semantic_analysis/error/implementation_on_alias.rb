module Jade
  module Frontend
    module SemanticAnalysis
      module Error
        class ImplementationOnAlias < Jade::Error
          def initialize(entry, span, interface:, alias_name:)
            super(entry:, span:)
            @interface = interface
            @alias_name = alias_name
          end

          def message
            "Cannot implement `#{@interface}` for type alias `#{@alias_name}`; " \
              "an alias is its body, so use a `struct` or a single-variant `type`"
          end

          def label
            "no impls on type aliases"
          end
        end
      end
    end
  end
end
