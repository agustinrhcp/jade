require 'spec_helper'

require 'jade'
require 'jade/module_loader'

module Jade
  describe 'deriving Changeset.Attribute' do
    include_context 'with test compiler'

    # Stands in for the app that owns the interface. The deriver matches on
    # exactly this shape, so this is also where that coupling is written down.
    let(:changeset_source) do
      <<~JADE.strip
        module Changeset exposing (Attribute, name, value)

        import Decode exposing (Value)


        interface Attribute(f) with
          name : f -> String,
          value : f -> Value
        end
      JADE
    end

    let(:fields_source) do
      <<~JADE.strip
        module Fields exposing (Field(..), encoded, label)

        import Decode exposing (Value)
        import Changeset exposing (Attribute, name, value)


        type Field
          = Name(String)
          | TargetCents(Maybe(Int))
          | DefaultEnvelopeId(Maybe(Int))


        def label(f: Field) -> String
          name(f)
        end


        def encoded(f: Field) -> Value
          value(f)
        end
      JADE
    end

    before do
      test_compiler.require(changeset_source)
      test_compiler.require(fields_source)
    end

    it 'names the slot after the variant, in snake_case' do
      expect(Fields::Internal.label(Fields::Name['rent'])).to eql 'name'
    end

    it 'splits a multi-word variant name' do
      expect(Fields::Internal.label(Fields::DefaultEnvelopeId[Maybe::Just[7]]))
        .to eql 'default_envelope_id'
    end

    it 'encodes the payload through Encodable' do
      expect(Fields::Internal.encoded(Fields::Name['rent'])).to eql 'rent'
    end

    it 'encodes a present optional as the value it holds' do
      expect(Fields::Internal.encoded(Fields::TargetCents[Maybe::Just[50]])).to eql 50
    end

    it 'encodes an absent optional as null, so a nullable slot can be cleared' do
      expect(Fields::Internal.encoded(Fields::TargetCents[Maybe::Nothing[]])).to be_nil
    end
  end
end
