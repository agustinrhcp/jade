module Jade
  module Interop
    module Guard
      class Error < StandardError
        attr_reader :expected, :actual, :reason, :index

        def initialize(reason, expected, actual, index = nil)
          @reason = reason
          @expected = expected
          @actual = actual
          @index = index
          super(message)
        end

        def message
          case reason
          in :wrong_type
            "Expected #{expected_to_ruby_class(expected)}, got #{actual} (#{actual.class})"

          in :missing_key
            "Expected Hash with key #{expected}, got #{actual}"

          in :nil_value
            "Expected non nil value #{expected_to_ruby_class(expected)}, got nil"

          in :invalid_list_element
            "Expected Array of #{expected_to_ruby_class(expected)}, got #{actual} (#{actual.class}) at #{index}"
          end
        end

        private

        def expected_to_ruby_class(expected)
          case expected
          in 'int' then 'Integer'
          in 'string' then 'String'
          in 'float' then 'Float'
          in 'bool' then 'true or false'
          end
        end
      end
    end
  end
end
