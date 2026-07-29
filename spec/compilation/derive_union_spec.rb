require 'spec_helper'

require 'jade'
require 'jade/module_loader'

module Jade
  describe 'deriving Encodable/Decodable for unions' do
    include_context 'with test compiler'

    before { test_compiler.require('enums', source) }

    let(:source) do
      <<~JADE
        module Enums exposing (Currency(..), Kind(..), dump, parse)

        import Decode exposing (DecodeError, Value)
        import Encode


        type Kind
          = Income
          | Expense


        type Currency
          = Usd
          | Uyu


        def dump(k: Kind) -> Value
          Encode.encode(k)
        end


        def parse(json: String) -> Result(Kind, DecodeError)
          Decode.from_json(json)
        end
      JADE
    end

    describe 'the derived encoder' do
      it 'writes a nullary variant as its snake_case name' do
        expect(Enums::Internal.dump(Enums::Income[])).to eql 'income'
      end

      it 'distinguishes the variants' do
        expect(Enums::Internal.dump(Enums::Expense[])).to eql 'expense'
      end
    end

    describe 'the derived decoder' do
      it 'reads a variant back' do
        expect(Enums::Internal.parse('"income"')).to be_ok(Enums::Income[])
      end

      it 'round-trips' do
        expect(Enums::Internal.parse(Enums::Internal.dump(Enums::Expense[]).to_json))
          .to be_ok(Enums::Expense[])
      end

      it 'fails on a string that names no variant' do
        expect(Enums::Internal.parse('"dividend"')).to be_err
      end

      it 'fails on a non-string' do
        expect(Enums::Internal.parse('42')).to be_err
      end
    end

    describe 'a struct with enum fields' do
      before { test_compiler.require('budget', envelope_source) }

      let(:envelope_source) do
        <<~JADE
          module Budget exposing (Cadence(..), Envelope(..), dump, parse)

          import Decode exposing (DecodeError, Value)
          import Encode


          type Cadence
            = Monthly
            | Goal


          struct Envelope = {
            name: String,
            cadence: Cadence
          }


          def dump(e: Envelope) -> Value
            Encode.encode(e)
          end


          def parse(json: String) -> Result(Envelope, DecodeError)
            Decode.from_json(json)
          end
        JADE
      end

      it 'derives through the enum instead of failing the whole struct' do
        expect(Budget::Internal.dump(Budget::Envelope['rent', Budget::Monthly[]]))
          .to eql({ 'name' => 'rent', 'cadence' => 'monthly' })
      end

      it 'reads one back' do
        expect(Budget::Internal.parse('{"name":"rent","cadence":"goal"}'))
          .to be_ok(Budget::Envelope['rent', Budget::Goal[]])
      end
    end

    describe 'a type sharing its name with its module' do
      before { test_compiler.require('envelope', shadow_source) }

      let(:shadow_source) do
        <<~JADE
          module Envelope exposing (Cadence(..), Envelope(..), dump)

          import Decode exposing (Value)
          import Encode


          type Cadence
            = Monthly
            | Goal


          struct Envelope = {
            name: String,
            cadence: Cadence
          }


          def dump(e: Envelope) -> Value
            Encode.encode(e)
          end
        JADE
      end

      it 'resolves the variant against the module, not the shadowing type' do
        expect(Envelope::Internal.dump(Envelope::Envelope['rent', Envelope::Monthly[]]))
          .to eql({ 'name' => 'rent', 'cadence' => 'monthly' })
      end
    end

    describe 'a hand-written implementation' do
      before { test_compiler.require('override', override_source) }

      let(:override_source) do
        <<~JADE
          module Override exposing (Currency(..), dump)

          import Decode exposing (Value)
          import Encode exposing (Encodable)


          type Currency
            = Usd
            | Uyu


          def encode_currency(c: Currency) -> Value
            case c
            in Usd then Encode.string("USD")
            in Uyu then Encode.string("UYU")
            end
          end


          implements Encodable(Currency) with
            encoder: encode_currency
          end


          def dump(c: Currency) -> Value
            Encode.encode(c)
          end
        JADE
      end

      it 'wins over the derived one' do
        expect(Override::Internal.dump(Override::Usd[])).to eql 'USD'
      end
    end
  end
end
