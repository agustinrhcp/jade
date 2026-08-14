require 'spec_helper'

require 'jade'
require 'jade/module_loader'

module Jade
  describe 'a type sharing its module name' do
    include_context 'with test compiler'

    context 'when it is a struct' do
      before { test_compiler.require(source) }

      let(:source) do
        <<~JADE
          module Probe exposing (Probe(..), make, unwrap)

          struct Probe = { n: Int }


          def make(n: Int) -> Probe
            Probe(n)
          end


          def unwrap(p: Probe) -> Int
            p.n
          end
        JADE
      end

      it 'constructs' do
        expect(::Probe.make(1)).to eql({ 'n' => 1 })
      end

      it 'round-trips through a function taking it' do
        expect(::Probe.unwrap(::Probe.make(7))).to be 7
      end
    end

    context 'when it is a union' do
      before { test_compiler.require(source) }

      let(:source) do
        <<~JADE
          module Signal exposing (Signal(..), flip, on)

          type Signal
            = On
            | Off


          def on -> Signal
            On
          end


          def flip(s: Signal) -> Signal
            case s
            in On then Off
            in Off then On
            end
          end
        JADE
      end

      it 'constructs and matches' do
        expect(::Signal.flip(::Signal.on)).to eql 'off'
      end
    end
  end
end
