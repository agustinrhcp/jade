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

      # Specialized fast-path validators. Emitted by codegen for known-shape
      # argument types in place of the generic `decode_or_raise` path —
      # avoids constructing a Decoder descriptor and walking the
      # interpreter for primitives.
      def integer(label, v)
        ::Integer === v ? v : type_error!(label, v)
      end

      def string(label, v)
        ::String === v ? v.dup : type_error!(label, v)
      end

      def bool(label, v)
        v == true || v == false ? v : type_error!(label, v)
      end

      def float(label, v)
        ::Numeric === v ? v.to_f : type_error!(label, v)
      end

      def list_of(klass, label, v)
        v.is_a?(::Array) && v.all? { klass === _1 } ? v : type_error!(label, v)
      end

      def hash(label, v)
        case v
        when ::Hash then v
        when ::Data then v.to_h.transform_keys(&:to_s)
        else type_error!(label, v)
        end
      end

      def type_error!(label, v)
        raise Jade::Interop::DecodeError.new(
          Jade::Decode::WrongType[label, Jade::Decode.type_name(v)],
          v,
        )
      end
    end
  end
end
