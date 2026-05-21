require 'spec_helper'

require 'jade'
require 'jade/module_loader'

module Jade
  describe 'Decode.Params' do
    include_context 'with test compiler'

    context 'PATCH-style: only present fields appear' do
      let(:source) do
        <<~JADE
          module PatchParams exposing (parse_fields)

          import Decode exposing (DecodeError)
          import Decode.Params exposing (Params)


          type Field
            = Name(String)
            | Age(Int)


          def patient_params -> Params(Field)
            Decode.Params.empty
              |> Decode.Params.string("name", Name)
              |> Decode.Params.int("age", Age)


          def parse_fields(json: String) -> Result(List(Field), DecodeError)
            Decode.decode_string(Decode.Params.collect(patient_params), json)
        JADE
      end

      before { test_compiler.require('patch_params', source) }

      it 'returns an empty list when no fields are present' do
        expect(PatchParams::Internal.parse_fields.call('{}')).to be_ok([])
      end

      it 'collects only the fields that were provided' do
        expect(PatchParams::Internal.parse_fields.call('{"name":"Pepe"}'))
          .to be_ok([PatchParams::Name['Pepe']])
      end

      it 'preserves build order, not input key order' do
        expect(PatchParams::Internal.parse_fields.call('{"age":30,"name":"Pepe"}'))
          .to be_ok([PatchParams::Name['Pepe'], PatchParams::Age[30]])
      end

      it 'fails when a present field has the wrong type' do
        result = PatchParams::Internal.parse_fields.call('{"name":42}')
        expect(result).to be_err
      end
    end

    context 'CREATE-style: defaults fill in absent fields' do
      let(:source) do
        <<~JADE
          module CreateParams exposing (parse_fields)

          import Decode exposing (DecodeError)
          import Decode.Params exposing (Params)


          type Field
            = Name(String)
            | Age(Int)


          def patient_params -> Params(Field)
            Decode.Params.empty
              |> Decode.Params.string("name", Name)
              |> Decode.Params.int("age", Age)
              |> Decode.Params.default("name", Name("anon"))
              |> Decode.Params.default("age", Age(0))


          def parse_fields(json: String) -> Result(List(Field), DecodeError)
            Decode.decode_string(Decode.Params.collect(patient_params), json)
        JADE
      end

      before { test_compiler.require('create_params', source) }

      it 'fills both defaults when both keys are absent' do
        expect(CreateParams::Internal.parse_fields.call('{}'))
          .to be_ok([CreateParams::Name['anon'], CreateParams::Age[0]])
      end

      it 'uses the present value over the default' do
        expect(CreateParams::Internal.parse_fields.call('{"name":"Pepe"}'))
          .to be_ok([CreateParams::Name['Pepe'], CreateParams::Age[0]])
      end
    end

    context 'multi-arg variant via inner pipeline' do
      let(:source) do
        <<~JADE
          module MultiArg exposing (parse)

          import Decode exposing (DecodeError)
          import Decode.Params exposing (Params)


          type Field
            = Coords(Int, Int)
            | Name(String)


          def coords_decoder -> Decode.Decoder(Field)
            Decode.succeed(Coords(_, _))
              |> Decode.required("x", Decode.int)
              |> Decode.required("y", Decode.int)


          def field_params -> Params(Field)
            Decode.Params.empty
              |> Decode.Params.string("name", Name)
              |> Decode.Params.accept("coords", coords_decoder)


          def parse(json: String) -> Result(List(Field), DecodeError)
            Decode.decode_string(Decode.Params.collect(field_params), json)
        JADE
      end

      before { test_compiler.require('multi_arg', source) }

      it 'decodes a multi-arg variant from a nested object' do
        expect(MultiArg::Internal.parse.call('{"coords":{"x":3,"y":7}}'))
          .to be_ok([MultiArg::Coords[3, 7]])
      end

      it 'decodes both fields together' do
        expect(MultiArg::Internal.parse.call('{"name":"Pepe","coords":{"x":1,"y":2}}'))
          .to be_ok([MultiArg::Name['Pepe'], MultiArg::Coords[1, 2]])
      end
    end

    context 'nested sub-params' do
      let(:source) do
        <<~JADE
          module Nested exposing (parse)

          import Decode exposing (DecodeError)
          import Decode.Params exposing (Params)


          type AddressField
            = Line1(String)
            | Line2(String)


          type Field
            = Name(String)
            | Address(List(AddressField))


          def address_params -> Params(AddressField)
            Decode.Params.empty
              |> Decode.Params.string("line1", Line1)
              |> Decode.Params.string("line2", Line2)


          def patient_params -> Params(Field)
            Decode.Params.empty
              |> Decode.Params.string("name", Name)
              |> Decode.Params.nested("address", Address, address_params)


          def parse(json: String) -> Result(List(Field), DecodeError)
            Decode.decode_string(Decode.Params.collect(patient_params), json)
        JADE
      end

      before { test_compiler.require('nested', source) }

      it 'decodes the outer field with an empty inner object' do
        expect(Nested::Internal.parse.call('{"address":{}}'))
          .to be_ok([Nested::Address[[]]])
      end

      it 'collects fields from the nested sub-params' do
        json = '{"name":"Pepe","address":{"line1":"123 Main","line2":"Apt 4"}}'
        expect(Nested::Internal.parse.call(json)).to be_ok([
          Nested::Name['Pepe'],
          Nested::Address[[
            Nested::Line1['123 Main'],
            Nested::Line2['Apt 4'],
          ]],
        ])
      end

      it 'omits the outer field entirely when its key is absent' do
        expect(Nested::Internal.parse.call('{"name":"Pepe"}'))
          .to be_ok([Nested::Name['Pepe']])
      end
    end
  end
end
