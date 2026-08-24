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

    context 'when two declarations share a name' do
      def expect_collision(source, message)
        expect { test_compiler.require(source) }
          .to raise_error(CompilationError, message)
      end

      it 'reports a struct and a type' do
        expect_collision(<<~JADE, /already declared as a type/)
          module ClashA exposing (Shape(..))

          struct Shape = { n: Int }


          type Shape
            = Round
            | Square
        JADE
      end

      it 'reports an interface after a type' do
        expect_collision(<<~JADE, /already declared as an interface/)
          module ClashB exposing (Shape(..), area)

          type Shape
            = Round
            | Square


          interface Shape(a) with
            area : a -> Int
          end
        JADE
      end

      it 'reports a type after an interface' do
        expect_collision(<<~JADE, /already declared as a type/)
          module ClashC exposing (Shape(..), area)

          interface Shape(a) with
            area : a -> Int
          end


          type Shape
            = Round
            | Square
        JADE
      end
    end
  end
end
