require 'spec_helper'

require 'jade'
require 'jade/module_loader'

module Jade
  describe 'an interface method referenced as a value' do
    include_context 'with test compiler'

    context 'when the interface type param is not in the parameter list' do
      before { test_compiler.require('cadence', source) }

      let(:source) do
        <<~JADE.strip
          module Cadence exposing (Cadence(..), from_field)

          import Decode exposing (DecodeError, Decoder)


          type Cadence
            = Monthly
            | Goal


          def field_decoder -> Decoder(Cadence)
            Decode.field("cadence", Decode.decoder)
          end


          def from_field(json: String) -> Result(Cadence, DecodeError)
            Decode.decode_string(field_decoder, json)
          end
        JADE
      end

      it 'resolves the instance from the expected type' do
        expect(Cadence::Internal.from_field('{"cadence":"monthly"}'))
          .to be_ok(Cadence::Monthly[])
      end

      it 'is still a real decoder, not a permissive one' do
        expect(Cadence::Internal.from_field('{"cadence":"weekly"}')).to be_err
      end
    end

    context 'a user-defined interface whose member takes no arguments' do
      before { test_compiler.require('defaults', source) }

      let(:source) do
        <<~JADE.strip
          module Defaults exposing (Default, Flag(..), blank, pick)

          interface Default(a) with
            blank : a
          end


          type Flag
            = On
            | Off


          implements Default(Flag) with
            blank: -> { Off }
          end


          def pick -> Flag
            blank
          end
        JADE
      end

      # Only `Inference::FunctionCall` attaches dictionaries, so a
      # reference outside an argument position reaches codegen with none
      # and emits a bare name. A separate bug from the one this file
      # covers, and a silent one: it compiles and fails at runtime.
      it 'is not specific to the stdlib' do
        pending 'dictionaries are attached at call sites only'

        expect(Defaults::Internal.pick).to eql Defaults::Off[]
      end
    end
  end
end
