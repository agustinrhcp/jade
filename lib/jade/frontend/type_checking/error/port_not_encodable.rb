module Jade
  module Frontend
    module TypeChecking
      module Error
        class PortNotEncodable < Jade::Error
          attr_reader :port_name, :position, :type

          def initialize(entry, span, port_name:, position:, type:)
            @port_name = port_name
            @position = position
            @type = type
            super(entry:, span:)
          end

          def message
            "Port `#{@port_name}` cannot encode argument #{@position} (`#{@type}`): " \
              "no Encodable instance"
          end

          def label
            "no Encodable instance for `#{@type}`"
          end

          def notes
            [
              Jade::Diagnostics::Annotation[
                :help,
                "implement Encodable for `#{@type}` so it can be encoded on the " \
                  "way out, or declare the argument as `Decode.Value` to hand " \
                  "Ruby the value untouched",
              ],
            ]
          end
        end
      end
    end
  end
end
