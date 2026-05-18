require 'jade/decode'
require 'jade/result'
require 'jade/interop/error'

module Jade
  module Interop
    module Boundary
      extend self

    # Boundary-side decode: succeed → return the value, fail → raise. The
    # Result wrap/unwrap that user-level Decode.from_value uses is dead
    # weight at the boundary because failure always raises anyway. Skipping
    # it removes one allocation per arg per Ruby→Jade call.
      def decode_or_raise(decoder, value)
        case Jade::Decode::Runner.run(decoder, value)
        in Jade::Result::Ok[v]  then v
        in Jade::Result::Err[e] then raise Jade::Interop::DecodeError.new(e, value)
        end
      end
    end
  end
end
