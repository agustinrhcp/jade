module Jade
  module Frontend
    module TypeChecking
      module Error
        class PortNotDecodable < Jade::Error
          attr_reader :port_name, :arm, :type

          def initialize(entry, span, port_name:, arm:, type:)
            @port_name = port_name
            @arm = arm
            @type = type
            super(entry:, span:)
          end

          def message
            "Port `#{@port_name}` cannot decode its #{@arm} arm (`#{@type}`): " \
              "no Decodable instance"
          end

          def label
            "no Decodable instance for `#{@type}`"
          end

          def notes
            [
              Jade::Diagnostics::Annotation[
                :help,
                "implement Decodable for `#{@type}` so it can be decoded " \
                  "automatically, or declare the port with `Decode.Value` " \
                  "to skip auto-decoding",
              ],
            ]
          end
        end
      end
    end
  end
end
