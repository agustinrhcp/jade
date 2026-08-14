require 'spec_helper'

require 'jade'
require 'jade/module_loader'

module Jade
  describe 'constructor codegen — curry safety' do
    include_context 'with test compiler'

    # Regression: a curried constructor built once and called on every
    # decode used to corrupt the heap under GC compaction when the curry
    # came from Ruby's Method#curry (a near-null "try to mark T_NONE
    # object" SIGSEGV). Derived record decoders no longer curry at all —
    # `Decode.record` applies every field in one call — so the hazard is
    # gone by construction here; the assertion stands for the constructors
    # that are still curried elsewhere. A Calendar.Date field forces the
    # interpreter boundary path (it can't be specialized inline).
    let(:source) do
      <<~JADE
        module M exposing (day_of)

        import Calendar


        struct P = {
          amount: Int,
          on: Calendar.Date
        }


        def day_of(p: P) -> Int
          p.amount
        end
      JADE
    end

    before { test_compiler.require(source) }

    it 'never builds a constructor with Method#curry' do
      expect(test_compiler.generated_source('m')).not_to include('.method(:[]).curry')
    end

    it 'applies the derived record constructor in one uncurried call' do
      generated = test_compiler.generated_source('m')
      expect(generated).to include('Jade::Runtime.intr("Decode.record")')
      expect(generated).to include('::M::P')
    end

    it 'still decodes the record across the boundary' do
      expect(M.day_of({ 'amount' => 42, 'on' => '2026-06-17' })).to eq 42
    end
  end
end

  describe '`^Ctor` sugar' do
    include_context 'with test compiler'

    it 'is the constructor curried, and equals the all-placeholder form' do
      test_compiler.require(<<~JADE)
        module Caret exposing (from_caret, from_placeholders)

        import Decode exposing (Decoder)


        struct C = {
          a: String,
          b: Bool
        }


        def caret_decoder -> Decoder(C)
          Decode.succeed(^C)
            |> Decode.and_map(Decode.field("a", Decode.string))
            |> Decode.and_map(Decode.field("b", Decode.bool))
        end


        def placeholder_decoder -> Decoder(C)
          Decode.succeed(C(_, _))
            |> Decode.and_map(Decode.field("a", Decode.string))
            |> Decode.and_map(Decode.field("b", Decode.bool))
        end


        def from_caret(json: String) -> Result(C, Decode.DecodeError)
          Decode.decode_string(caret_decoder, json)
        end


        def from_placeholders(json: String) -> Result(C, Decode.DecodeError)
          Decode.decode_string(placeholder_decoder, json)
        end
      JADE

      json = '{"a": "x", "b": true}'
      expect(Caret::Internal.from_caret(json)).to eql Caret::Internal.from_placeholders(json)
      expect(Caret::Internal.from_caret(json)).to be_ok(have_attributes(a: 'x', b: true))
    end

    it 'curries a variant constructor too' do
      test_compiler.require(<<~JADE)
        module CaretVariant exposing (run)

        type Pair = Pair(Int, Int)


        def run -> Pair
          apply(^Pair)
        end


        def apply(f: Int -> (Int -> Pair)) -> Pair
          f(1)(2)
        end
      JADE

      expect(CaretVariant::Internal.run).to look_like(:Pair, 1, 2)
    end
  end
