require 'spec_helper'

require 'jade'

module Jade
  describe 'Bytes' do
    include_context 'with test compiler'

    let(:source) do
      <<~JADE
        module Pepe exposing (
          append,
          bad_list,
          bad_string,
          decode_bytes,
          empty_width,
          encode_bytes,
          eq,
          roundtrip_list,
          roundtrip_string,
          which_end,
          width_of,
        )

        import Bytes exposing (Endianness(..))
        import Decode exposing (DecodeError)
        import Encode

        def empty_width() -> Int
          Bytes.width(Bytes.empty())
        end

        def roundtrip_list(xs: List(Int)) -> Maybe(List(Int))
          case Bytes.from_list(xs)
          of Just(b) then Just(Bytes.to_list(b))
          of Nothing then Nothing
          end
        end

        def bad_list() -> Maybe(Bytes)
          Bytes.from_list([0, 256])
        end

        def roundtrip_string(s: String) -> Maybe(String)
          Bytes.to_string(Bytes.from_string(s))
        end

        def bad_string() -> Maybe(String)
          case Bytes.from_list([255, 254])
          of Just(b) then Bytes.to_string(b)
          of Nothing then Nothing
          end
        end

        def width_of(xs: List(Int)) -> Maybe(Int)
          case Bytes.from_list(xs)
          of Just(b) then Just(Bytes.width(b))
          of Nothing then Nothing
          end
        end

        def append(xs: List(Int), ys: List(Int)) -> Maybe(List(Int))
          case (Bytes.from_list(xs), Bytes.from_list(ys))
          of (Just(a), Just(b)) then Just(Bytes.to_list(cat(a, b)))
          of _ then Nothing
          end
        end

        def cat(a: Bytes, b: Bytes) -> Bytes
          a ++ b
        end

        def eq(xs: List(Int), ys: List(Int)) -> Maybe(Bool)
          case (Bytes.from_list(xs), Bytes.from_list(ys))
          of (Just(a), Just(b)) then Just(same(a, b))
          of _ then Nothing
          end
        end

        def same(a: Bytes, b: Bytes) -> Bool
          a == b
        end

        def which_end(e: Endianness) -> String
          case e
          of LE then "little"
          of BE then "big"
          end
        end

        def encode_bytes(b: Bytes) -> String
          Encode.encode_to_string(Encode.encode(b))
        end

        def decode_bytes(json: String) -> Result(Bytes, DecodeError)
          Decode.from_json(json)
        end
      JADE
    end

    before { test_compiler.require('pepe', source) }

    it 'empty has width 0' do
      expect(Pepe.empty_width.call).to eql 0
    end

    it 'roundtrips a list of bytes' do
      expect(Pepe.roundtrip_list.call([])).to be_just([])
      expect(Pepe.roundtrip_list.call([1, 2, 3])).to be_just([1, 2, 3])
      expect(Pepe.roundtrip_list.call([0, 255])).to be_just([0, 255])
    end

    it 'rejects out-of-range ints' do
      expect(Pepe.bad_list.call).to be_nothing
    end

    it 'roundtrips a UTF-8 string' do
      expect(Pepe.roundtrip_string.call('hi')).to be_just('hi')
      expect(Pepe.roundtrip_string.call('café ☕')).to be_just('café ☕')
      expect(Pepe.roundtrip_string.call('')).to be_just('')
    end

    it 'returns Nothing for invalid UTF-8' do
      expect(Pepe.bad_string.call).to be_nothing
    end

    it 'reports width' do
      expect(Pepe.width_of.call([1, 2, 3, 4])).to be_just(4)
    end

    it 'appends via Appendable' do
      expect(Pepe.append.call([1, 2], [3, 4])).to be_just([1, 2, 3, 4])
      expect(Pepe.append.call([], [9])).to be_just([9])
    end

    it 'compares via Eq' do
      expect(Pepe.eq.call([1, 2], [1, 2])).to be_just(true)
      expect(Pepe.eq.call([1, 2], [1, 3])).to be_just(false)
    end

    it 'matches on Endianness variants' do
      expect(Pepe.which_end.call(Jade::Bytes::LE[])).to eql 'little'
      expect(Pepe.which_end.call(Jade::Bytes::BE[])).to eql 'big'
    end

    it 'roundtrips through JSON via Encodable/Decodable (base64)' do
      json = Pepe.encode_bytes.call(Jade::Bytes::Bytes['hi'])
      expect(json).to eql '"aGk="'
      expect(Pepe.decode_bytes.call(json)).to be_ok(Jade::Bytes::Bytes['hi'])
    end

    it 'rejects invalid base64' do
      expect(Pepe.decode_bytes.call('"not base64!"')).to be_err
    end
  end
end
