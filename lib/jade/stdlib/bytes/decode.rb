require 'jade/stdlib/intrinsics'
require 'jade/stdlib/bytes'

module Jade
  module Stdlib
    module Bytes
      module Decode
        extend Intrinsics

        def self.module_name = 'Bytes.Decode'

        import Basics
        import Maybe
        import Bytes

        union :Decoder, 'a'

        function(
          'decode',
          { decoder: 'Bytes.Decode.Decoder(a)', bytes: 'Bytes.Bytes' },
          'Maybe(a)',
        ) { |decoder, bytes|
          case decoder.run.call(bytes.bin, 0)
          in Jade::Maybe::Just[[value, _offset]] then Jade::Maybe::Just[value]
          in Jade::Maybe::Nothing then Jade::Maybe::Nothing[]
          end
        }

        function(
          'succeed',
          { value: 'a' },
          'Bytes.Decode.Decoder(a)',
        ) { |value|
          Jade::Bytes::Decode::Decoder[->(_bin, offset) { Jade::Maybe::Just[[value, offset]] }]
        }

        function(
          'fail',
          {},
          'Bytes.Decode.Decoder(a)',
        ) {
          Jade::Bytes::Decode::Decoder[->(_bin, _offset) { Jade::Maybe::Nothing[] }]
        }

        function(
          'map',
          { decoder: 'Bytes.Decode.Decoder(a)', fn: 'a -> b' },
          'Bytes.Decode.Decoder(b)',
        ) { |decoder, fn|
          Jade::Bytes::Decode::Decoder[->(bin, offset) {
            case decoder.run.call(bin, offset)
            in Jade::Maybe::Just[[value, new_offset]] then Jade::Maybe::Just[[fn.call(value), new_offset]]
            in Jade::Maybe::Nothing then Jade::Maybe::Nothing[]
            end
          }]
        }

        function(
          'and_then',
          { decoder: 'Bytes.Decode.Decoder(a)', fn: 'a -> Bytes.Decode.Decoder(b)' },
          'Bytes.Decode.Decoder(b)',
        ) { |decoder, fn|
          Jade::Bytes::Decode::Decoder[->(bin, offset) {
            case decoder.run.call(bin, offset)
            in Jade::Maybe::Just[[value, mid_offset]] then fn.call(value).run.call(bin, mid_offset)
            in Jade::Maybe::Nothing then Jade::Maybe::Nothing[]
            end
          }]
        }

        function(
          'signed_int8',
          {},
          'Bytes.Decode.Decoder(Int)',
        ) {
          Jade::Bytes::Decode::Decoder[->(bin, offset) {
            offset + 1 > bin.bytesize \
              ? Jade::Maybe::Nothing[]
              : Jade::Maybe::Just[[bin.byteslice(offset, 1).unpack1('c'), offset + 1]]
          }]
        }

        function(
          'unsigned_int8',
          {},
          'Bytes.Decode.Decoder(Int)',
        ) {
          Jade::Bytes::Decode::Decoder[->(bin, offset) {
            offset + 1 > bin.bytesize \
              ? Jade::Maybe::Nothing[]
              : Jade::Maybe::Just[[bin.byteslice(offset, 1).unpack1('C'), offset + 1]]
          }]
        }

        function(
          'signed_int16',
          { endianness: 'Bytes.Endianness' },
          'Bytes.Decode.Decoder(Int)',
        ) { |e|
          fmt = e.is_a?(Jade::Bytes::LE) ? 's<' : 's>'
          Jade::Bytes::Decode::Decoder[->(bin, offset) {
            offset + 2 > bin.bytesize \
              ? Jade::Maybe::Nothing[]
              : Jade::Maybe::Just[[bin.byteslice(offset, 2).unpack1(fmt), offset + 2]]
          }]
        }

        function(
          'unsigned_int16',
          { endianness: 'Bytes.Endianness' },
          'Bytes.Decode.Decoder(Int)',
        ) { |e|
          fmt = e.is_a?(Jade::Bytes::LE) ? 'S<' : 'S>'
          Jade::Bytes::Decode::Decoder[->(bin, offset) {
            offset + 2 > bin.bytesize \
              ? Jade::Maybe::Nothing[]
              : Jade::Maybe::Just[[bin.byteslice(offset, 2).unpack1(fmt), offset + 2]]
          }]
        }

        function(
          'signed_int32',
          { endianness: 'Bytes.Endianness' },
          'Bytes.Decode.Decoder(Int)',
        ) { |e|
          fmt = e.is_a?(Jade::Bytes::LE) ? 'l<' : 'l>'
          Jade::Bytes::Decode::Decoder[->(bin, offset) {
            offset + 4 > bin.bytesize \
              ? Jade::Maybe::Nothing[]
              : Jade::Maybe::Just[[bin.byteslice(offset, 4).unpack1(fmt), offset + 4]]
          }]
        }

        function(
          'unsigned_int32',
          { endianness: 'Bytes.Endianness' },
          'Bytes.Decode.Decoder(Int)',
        ) { |e|
          fmt = e.is_a?(Jade::Bytes::LE) ? 'L<' : 'L>'
          Jade::Bytes::Decode::Decoder[->(bin, offset) {
            offset + 4 > bin.bytesize \
              ? Jade::Maybe::Nothing[]
              : Jade::Maybe::Just[[bin.byteslice(offset, 4).unpack1(fmt), offset + 4]]
          }]
        }

        function(
          'float32',
          { endianness: 'Bytes.Endianness' },
          'Bytes.Decode.Decoder(Float)',
        ) { |e|
          fmt = e.is_a?(Jade::Bytes::LE) ? 'e' : 'g'
          Jade::Bytes::Decode::Decoder[->(bin, offset) {
            offset + 4 > bin.bytesize \
              ? Jade::Maybe::Nothing[]
              : Jade::Maybe::Just[[bin.byteslice(offset, 4).unpack1(fmt), offset + 4]]
          }]
        }

        function(
          'float64',
          { endianness: 'Bytes.Endianness' },
          'Bytes.Decode.Decoder(Float)',
        ) { |e|
          fmt = e.is_a?(Jade::Bytes::LE) ? 'E' : 'G'
          Jade::Bytes::Decode::Decoder[->(bin, offset) {
            offset + 8 > bin.bytesize \
              ? Jade::Maybe::Nothing[]
              : Jade::Maybe::Just[[bin.byteslice(offset, 8).unpack1(fmt), offset + 8]]
          }]
        }

        function(
          'string',
          { n: 'Int' },
          'Bytes.Decode.Decoder(String)',
        ) { |n|
          Jade::Bytes::Decode::Decoder[->(bin, offset) {
            if offset + n > bin.bytesize
              Jade::Maybe::Nothing[]
            else
              s = bin.byteslice(offset, n).dup.force_encoding(Encoding::UTF_8)
              s.valid_encoding? ? Jade::Maybe::Just[[s, offset + n]] : Jade::Maybe::Nothing[]
            end
          }]
        }

        function(
          'bytes',
          { n: 'Int' },
          'Bytes.Decode.Decoder(Bytes.Bytes)',
        ) { |n|
          Jade::Bytes::Decode::Decoder[->(bin, offset) {
            offset + n > bin.bytesize \
              ? Jade::Maybe::Nothing[]
              : Jade::Maybe::Just[[Jade::Bytes::Bytes[bin.byteslice(offset, n)], offset + n]]
          }]
        }
      end
    end
  end
end
