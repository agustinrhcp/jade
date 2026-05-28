require 'spec_helper'

require 'jade'
require 'jade/module_loader'

module Jade
  describe 'Wrapping unions (single-variant peel)' do
    include_context 'with test compiler'

    describe 'Encode peels the wrapper' do
      before do
        test_compiler.require('user_ids_enc', source)
      end

      let(:source) do
        <<~JADE
          module UserIdsEnc exposing (mint)

          type UserId = UserId(Int)


          def mint -> UserId
            UserId(42)
        JADE
      end

      it 'a single-variant union encodes as the inner value' do
        expect(UserIdsEnc.mint).to eql 42
      end
    end

    describe 'Decode peels into the wrapper' do
      before do
        test_compiler.require('user_ids_dec', source)
      end

      let(:source) do
        <<~JADE
          module UserIdsDec exposing (next_id)

          type UserId = UserId(Int)


          def next_id(id: UserId) -> UserId
            UserId(n) = id

            UserId(n + 1)
        JADE
      end

      it 'a single-variant union decodes from the inner value' do
        expect(UserIdsDec.next_id(41)).to eql 42
      end
    end

    describe 'parameterised wrapping union' do
      before do
        test_compiler.require('boxed', source)
      end

      let(:source) do
        <<~JADE
          module Boxed exposing (mk)

          type Box(a) = Box(a)


          def mk -> Box(Int)
            Box(7)
        JADE
      end

      it 'peeling works through a type parameter' do
        expect(Boxed.mk).to eql 7
      end
    end

    describe 'multi-variant unions do not peel' do
      let(:source) do
        <<~JADE
          module Multi exposing (mk)

          type Shape
            = Circle(Float)
            | Square(Float)


          def mk -> Shape
            Circle(1.0)
        JADE
      end

      it 'multi-variant unions still need an explicit impl' do
        test_compiler.require('multi', source)
        expect { Multi.mk }.to raise_error(Jade::Interop::NotExposed, /Encodable|encoder/i)
      end
    end
  end
end
