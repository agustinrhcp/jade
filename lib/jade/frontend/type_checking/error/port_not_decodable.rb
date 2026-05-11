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
              "no Decodable instance. Implement Decodable for `#{@type}` " \
              "or declare the port with Decode.Value."
          end
        end
      end
    end
  end
end
