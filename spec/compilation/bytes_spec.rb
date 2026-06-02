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
          empty_width,
          eq,
          roundtrip_list,
          roundtrip_string,
          width_of,
        )

        def empty_width -> Int
          Bytes.width(Bytes.empty)
        end


        def roundtrip_list(xs: List(Int)) -> Maybe(List(Int))
          case Bytes.from_list(xs)
          in Just(b) then Just(Bytes.to_list(b))
          in Nothing then Nothing
          end
        end


        def bad_list -> Maybe(Bytes)
          Bytes.from_list([0, 256])
        end


        def roundtrip_string(s: String) -> Maybe(String)
          Bytes.to_string(Bytes.from_string(s))
        end


        def bad_string -> Maybe(String)
          case Bytes.from_list([255, 254])
          in Just(b) then Bytes.to_string(b)
          in Nothing then Nothing
          end
        end


        def width_of(xs: List(Int)) -> Maybe(Int)
          case Bytes.from_list(xs)
          in Just(b) then Just(Bytes.width(b))
          in Nothing then Nothing
          end
        end


        def append(xs: List(Int), ys: List(Int)) -> Maybe(List(Int))
          case (Bytes.from_list(xs), Bytes.from_list(ys))
          in (Just(a), Just(b)) then Just(Bytes.to_list(cat(a, b)))
          else Nothing
          end
        end


        def cat(a: Bytes, b: Bytes) -> Bytes
          a ++ b
        end


        def eq(xs: List(Int), ys: List(Int)) -> Maybe(Bool)
          case (Bytes.from_list(xs), Bytes.from_list(ys))
          in (Just(a), Just(b)) then Just(same(a, b))
          else Nothing
          end
        end


        def same(a: Bytes, b: Bytes) -> Bool
          a == b
        end
      JADE
    end

    before { test_compiler.require('pepe', source) }

    it 'empty has width 0' do
      expect(Pepe.empty_width).to eql 0
    end

    it 'roundtrips a list of bytes' do
      expect(Pepe.roundtrip_list([])).to eql []
      expect(Pepe.roundtrip_list([1, 2, 3])).to eql [1, 2, 3]
      expect(Pepe.roundtrip_list([0, 255])).to eql [0, 255]
    end

    it 'rejects out-of-range ints' do
      expect(Pepe::Internal.bad_list).to be_nothing
    end

    it 'roundtrips a UTF-8 string' do
      expect(Pepe.roundtrip_string('hi')).to eql 'hi'
      expect(Pepe.roundtrip_string('café ☕')).to eql 'café ☕'
      expect(Pepe.roundtrip_string('')).to eql ''
    end

    it 'returns Nothing for invalid UTF-8' do
      expect(Pepe.bad_string).to be_nil
    end

    it 'reports width' do
      expect(Pepe.width_of([1, 2, 3, 4])).to eql 4
    end

    it 'appends via Appendable' do
      expect(Pepe.append([1, 2], [3, 4])).to eql [1, 2, 3, 4]
      expect(Pepe.append([], [9])).to eql [9]
    end

    it 'compares via Eq' do
      expect(Pepe.eq([1, 2], [1, 2])).to be true
      expect(Pepe.eq([1, 2], [1, 3])).to be false
    end

  end
end
