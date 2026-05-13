module Jade
  module Frontend
    module TypeChecking
      module Error
        class PortNotDecodable < Jade::Error
          attr_reader :port_name, :arm, :type, :reason

          def initialize(entry, span, port_name:, arm:, type:, reason: :no_impl)
            @port_name = port_name
            @arm = arm
            @type = type
            @reason = reason
            super(entry:, span:)
          end

          def message
            case @reason
            in :compound_var
              "Port `#{@port_name}` cannot decode its #{@arm} arm (`#{@type}`): " \
                "polymorphic ports only support bare type parameters in arms. " \
                "Nested shapes like `List(a)` or `Maybe(a)` are not yet supported. " \
                "Use `Decode.Value` if you want to skip auto-decoding."

            in :no_impl
              "Port `#{@port_name}` cannot decode its #{@arm} arm (`#{@type}`): " \
                "no Decodable instance. Implement Decodable for `#{@type}` " \
                "or declare the port with Decode.Value."
            end
          end
        end
      end
    end
  end
end
