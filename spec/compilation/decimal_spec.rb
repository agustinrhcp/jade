require 'spec_helper'

require 'jade'
require 'jade/module_loader'

module Jade
  describe 'Decimal' do
    include_context 'with test compiler'

    let(:source) do
      <<~JADE
        module M exposing (
          added,
          divided,
          is_bad,
          of_float,
          parsed,
          rounded_coeff,
          roundtrip,
          scaled_float,
          wire,
        )

        import Decimal exposing (Decimal)
        import Encode exposing (encode, encode_to_string)
        import Decode exposing (DecodeError)


        def of_float(coeff: Int, exp: Int) -> Float
          Decimal.to_float(Decimal.of(coeff, exp))
        end


        def scaled_float(unscaled: Int, scale: Int) -> Float
          Decimal.to_float(Decimal.scaled(unscaled, scale))
        end


        def parsed(s: String) -> Float
          case Decimal.parse(s)
          in Just(d) then Decimal.to_float(d)
          else 0.0 - 1.0
          end
        end


        def is_bad(s: String) -> Bool
          case Decimal.parse(s)
          in Nothing then True
          else False
          end
        end


        def divided(an: Int, ae: Int, bn: Int, be: Int, scale: Int) -> Float
          Decimal.to_float(Decimal.div(Decimal.of(an, ae), Decimal.of(bn, be), scale))
        end


        def rounded_coeff(coeff: Int, exp: Int, scale: Int) -> Int
          Decimal.coefficient(Decimal.round(Decimal.of(coeff, exp), scale))
        end


        def added(an: Int, ae: Int, bn: Int, be: Int) -> Float
          Decimal.to_float(Decimal.of(an, ae) + Decimal.of(bn, be))
        end


        def wire(coeff: Int, exp: Int) -> String
          encode_to_string(encode(Decimal.of(coeff, exp)))
        end


        def roundtrip(json: String) -> Result(Decimal, DecodeError)
          Decode.from_json(json)
        end
      JADE
    end

    before { test_compiler.require('m', source) }

    describe 'construction' do
      it 'of is coefficient * 10 ^ exponent' do
        expect(M.of_float(825, -4)).to eq 0.0825
      end

      it 'scaled(u, s) == of(u, -s)' do
        expect(M.scaled_float(825, 4)).to eq 0.0825
      end
    end

    describe 'parse' do
      it 'reads a fractional string' do
        expect(M.parsed('0.0825')).to eq 0.0825
      end

      it 'reads a negative' do
        expect(M.parsed('-12.5')).to eq(-12.5)
      end

      it 'reads a bare integer' do
        expect(M.parsed('42')).to eq 42.0
      end

      it 'rejects a non-numeral' do
        expect(M.is_bad('nope')).to be true
      end
    end

    describe 'arithmetic' do
      it 'divides half-up to a scale' do
        expect(M.divided(1, 0, 3, 0, 4)).to eq 0.3333
      end

      it 'rounds half-up' do
        # 12.345 rounded to 2 places -> 12.35, coefficient 1235
        expect(M.rounded_coeff(12345, -3, 2)).to eq 1235
      end

      it 'adds via the Numeric operator' do
        expect(M.added(1, 0, 5, -1)).to eq 1.5
      end
    end

    describe 'JSON boundary' do
      it 'encodes to the <mantissa>e<exponent> wire form (a JSON string)' do
        expect(M.wire(825, -4)).to eq '"825e-4"'
      end

      it 'decodes the wire form back' do
        expect(M::Internal.roundtrip('"825e-4"'))
          .to be_ok(have_attributes(_1: 825, _2: -4))
      end
    end
  end
end
