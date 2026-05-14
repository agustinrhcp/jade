require 'spec_helper'

require 'jade'

module Jade
  describe 'Bytes.Encode / Bytes.Decode' do
    include_context 'with test compiler'

    let(:source) do
      <<~JADE
        module Pepe exposing (
          fail_short,
          framed,
          parse_pair,
          round_bytes,
          round_f32,
          round_f64,
          round_i32,
          round_i8,
          round_str,
          round_u16_be,
          round_u16_le,
          round_u32,
          round_u8,
        )

        import Bytes exposing (Bytes, Endianness(..))
        import Bytes.Encode
        import Bytes.Decode

        def round_u8(n: Int) -> Maybe(Int)
          decode_one(Bytes.Encode.unsigned_int8(n), Bytes.Decode.unsigned_int8())
        end

        def round_i8(n: Int) -> Maybe(Int)
          decode_one(Bytes.Encode.signed_int8(n), Bytes.Decode.signed_int8())
        end

        def round_u16_be(n: Int) -> Maybe(Int)
          decode_one(Bytes.Encode.unsigned_int16(BE, n), Bytes.Decode.unsigned_int16(BE))
        end

        def round_u16_le(n: Int) -> Maybe(Int)
          decode_one(Bytes.Encode.unsigned_int16(LE, n), Bytes.Decode.unsigned_int16(LE))
        end

        def round_u32(n: Int) -> Maybe(Int)
          decode_one(Bytes.Encode.unsigned_int32(BE, n), Bytes.Decode.unsigned_int32(BE))
        end

        def round_i32(n: Int) -> Maybe(Int)
          decode_one(Bytes.Encode.signed_int32(LE, n), Bytes.Decode.signed_int32(LE))
        end

        def round_f32(f: Float) -> Maybe(Float)
          decode_one(Bytes.Encode.float32(BE, f), Bytes.Decode.float32(BE))
        end

        def round_f64(f: Float) -> Maybe(Float)
          decode_one(Bytes.Encode.float64(LE, f), Bytes.Decode.float64(LE))
        end

        def round_str(s: String) -> Maybe(String)
          b = Bytes.Encode.encode(Bytes.Encode.string(s))

          Bytes.Decode.decode(Bytes.Decode.string(Bytes.width(b)), b)
        end

        def round_bytes(xs: List(Int)) -> Maybe(List(Int))
          case Bytes.from_list(xs)
          of Just(b) then
            inner = Bytes.Encode.encode(Bytes.Encode.bytes(b))

            case Bytes.Decode.decode(Bytes.Decode.bytes(Bytes.width(inner)), inner)
            of Just(out) then Just(Bytes.to_list(out))
            of Nothing then Nothing
            end
          of Nothing then Nothing
          end
        end

        def fail_short() -> Maybe(Int)
          decode_one(Bytes.Encode.unsigned_int8(7), Bytes.Decode.unsigned_int32(BE))
        end

        def framed(n: Int, payload: String) -> Bytes
          Bytes.Encode.encode(
            Bytes.Encode.sequence([
              Bytes.Encode.unsigned_int16(BE, n),
              Bytes.Encode.string(payload),
            ]),
          )
        end

        def parse_pair(b: Bytes) -> Maybe((Int, Int))
          pair_decoder() |> (d) -> { Bytes.Decode.decode(d, b) }
        end

        def pair_decoder() -> Bytes.Decode.Decoder((Int, Int))
          Bytes.Decode.unsigned_int16(BE) |> Bytes.Decode.and_then(read_second)
        end

        def read_second(first: Int) -> Bytes.Decode.Decoder((Int, Int))
          Bytes.Decode.unsigned_int16(BE) |> Bytes.Decode.map((second) -> { (first, second) })
        end

        def decode_one(e: Bytes.Encode.Encoder, d: Bytes.Decode.Decoder(a)) -> Maybe(a)
          Bytes.Decode.decode(d, Bytes.Encode.encode(e))
        end
      JADE
    end

    before { test_compiler.require('pepe', source) }

    it 'roundtrips unsigned int 8' do
      expect(Pepe.round_u8.call(0)).to be_just(0)
      expect(Pepe.round_u8.call(255)).to be_just(255)
    end

    it 'roundtrips signed int 8' do
      expect(Pepe.round_i8.call(-128)).to be_just(-128)
      expect(Pepe.round_i8.call(127)).to be_just(127)
    end

    it 'roundtrips unsigned int 16 in either endianness' do
      expect(Pepe.round_u16_be.call(0xABCD)).to be_just(0xABCD)
      expect(Pepe.round_u16_le.call(0xABCD)).to be_just(0xABCD)
      expect(Pepe.round_u16_be.call(0)).to be_just(0)
      expect(Pepe.round_u16_be.call(65535)).to be_just(65535)
    end

    it 'roundtrips unsigned int 32' do
      expect(Pepe.round_u32.call(0xDEADBEEF)).to be_just(0xDEADBEEF)
    end

    it 'roundtrips signed int 32' do
      expect(Pepe.round_i32.call(-2_000_000_000)).to be_just(-2_000_000_000)
    end

    it 'roundtrips float32 (with rounding)' do
      result = Pepe.round_f32.call(1.5)
      expect(result).to be_just(1.5)
    end

    it 'roundtrips float64 exactly' do
      expect(Pepe.round_f64.call(3.141592653589793)).to be_just(3.141592653589793)
    end

    it 'roundtrips strings (UTF-8)' do
      expect(Pepe.round_str.call('')).to be_just('')
      expect(Pepe.round_str.call('hello')).to be_just('hello')
      expect(Pepe.round_str.call('café ☕')).to be_just('café ☕')
    end

    it 'roundtrips bytes' do
      expect(Pepe.round_bytes.call([1, 2, 3])).to be_just([1, 2, 3])
      expect(Pepe.round_bytes.call([])).to be_just([])
    end

    it 'returns Nothing when the input is too short' do
      expect(Pepe.fail_short.call).to be_nothing
    end

    it 'sequence concatenates encoders, predictable wire format' do
      bytes = Pepe.framed.call(3, 'hi!')
      expect(bytes.bin.bytes).to eql [0x00, 0x03, 0x68, 0x69, 0x21]
      expect(bytes.bin.bytesize).to eql 5
    end

    it 'composes decoders with and_then / map' do
      bytes = Pepe.framed.call(0x0102, '').then { Jade::Bytes::Bytes[it.bin + [0x03, 0x04].pack('C*')] }
      expect(Pepe.parse_pair.call(bytes)).to be_just(Jade::Tuple::Tuple2[0x0102, 0x0304])
    end
  end
end
