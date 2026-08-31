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

    context 'when a sibling type is referenced from inside it' do
      before { test_compiler.require(source) }

      let(:source) do
        <<~JADE
          module Plan exposing (Building(..), Plan(..), build, go)

          type Plan
            = Draft
            | Live(Int)


          type Building = Building(Int)


          def build(b: Building) -> Int
            case b
            in Building(n) then n
            end
          end


          def go -> Int
            build(Building(3))
          end
        JADE
      end

      it 'matches a sibling constructor and calls its own Internal' do
        expect(::Plan.go).to be 3
      end
    end

    context 'when the same declaration is written twice' do
      it 'reports the second, naming the first' do
        source = <<~JADE
          module DupType exposing (AgeTiers(..))

          type AgeTiers
            = Open(Int)
            | UpTo(Int)


          type AgeTiers
            = Open(Int)
            | UpTo(Int)
        JADE

        expect { test_compiler.require(source) }
          .to raise_error(CompilationError, /`AgeTiers` is already declared as a type in this module/)
      end

      it 'reports a struct written twice' do
        source = <<~JADE
          module DupStruct exposing (Point(..))

          struct Point = { x: Int }


          struct Point = { x: Int }
        JADE

        expect { test_compiler.require(source) }
          .to raise_error(CompilationError, /`Point` is already declared as a struct in this module/)
      end
    end

    context 'when two types share a constructor' do
      it 'reports it, rather than shadowing one and failing to resolve it' do
        source = <<~JADE
          module DupCtor exposing (Card(..), Invoice(..))

          type Invoice
            = Pending
            | Paid


          type Card
            = Pending
            | Active
        JADE

        expect { test_compiler.require(source) }
          .to raise_error(CompilationError, /`Pending` is already a constructor of `Invoice`/)
      end

      it 'reports a variant clashing with a struct, which declares one too' do
        source = <<~JADE
          module CtorStructFirst exposing (Invoice(..), Pending(..))

          struct Pending = { at: Int }


          type Invoice
            = Pending
            | Paid
        JADE

        expect { test_compiler.require(source) }
          .to raise_error(CompilationError, /`Pending` is already a struct in this module/)
      end

      it 'reports a struct clashing with a variant declared before it' do
        source = <<~JADE
          module CtorVariantFirst exposing (Invoice(..), Pending(..))

          type Invoice
            = Pending
            | Paid


          struct Pending = { at: Int }
        JADE

        expect { test_compiler.require(source) }
          .to raise_error(CompilationError, /`Pending` is already a constructor of `Invoice`/)
      end

      it 'still declares the type, so a signature naming it reads normally' do
        source = <<~JADE
          module DupCtorSig exposing (Card(..), Invoice(..), latest)

          type Invoice
            = Pending
            | Paid


          type Card
            = Pending
            | Active


          def latest -> Card
            Active
          end
        JADE

        expect { test_compiler.require(source) }
          .to raise_error(CompilationError) { |e| expect(e.message).not_to match(/Card.*not found/) }
      end
    end

    context 'when two declarations share a name' do
      def expect_collision(source, message)
        expect { test_compiler.require(source) }
          .to raise_error(CompilationError, message)
      end

      it 'reports a struct and a type' do
        expect_collision(<<~JADE, /`Shape` is already declared as a struct/)
          module ClashA exposing (Shape(..))

          struct Shape = { n: Int }


          type Shape
            = Round
            | Square
        JADE
      end

      it 'reports an interface after a type' do
        expect_collision(<<~JADE, /`Shape` is already declared as a type/)
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
        expect_collision(<<~JADE, /`Shape` is already declared as an interface/)
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
