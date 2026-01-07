require 'spec_helper'

require 'jade'
require 'jade/module_loader'

module Jade
  describe 'examples' do
    let(:maybe_source) do
      <<~JADE
        module Maybe exposing (map, with_default)

        type Maybe = Just(a) | Nothing

        def with_default(maybe: Maybe(a), default: a) -> a
          case maybe
          of Just(something) then something
          of Nothing then default
          end
        end

        def map(maybe: Maybe(a), fn: a -> b) -> Maybe(b)
          case maybe
          of Just(something) then
            Just(fn(something))

          of Nothing then
            maybe
          end
        end
      JADE
    end

    describe 'requiring the generated file' do
      include_context 'with test compiler'

      before do
        test_compiler.require('maybe', maybe_source)
      end

      it 'works' do
        expect(Maybe.with_default.call(Maybe::Just[2], 0)).to be 2
        expect(Maybe.with_default.call(Maybe::Nothing[], 0)).to be 0
      end
    end

    context 'test import' do
      include_context 'with test compiler'

      let(:pepe_source) do
        <<~JADE
          module Pepe exposing (hello)

          import Maybe

          def hello(maybe: Maybe(String)) -> String
            Maybe.with_default(maybe, "Hello pepe")
          end

          def sum_maybe(maybe: Maybe(Int), n: Int) -> Int
            Maybe.with_default(Maybe.map(maybe, (m) -> { m + n }), 0)
          end
        JADE
      end

      before do
        test_compiler.require('maybe', maybe_source)
        test_compiler.require('pepe', pepe_source)
      end

      it 'works' do
        expect(Pepe.hello.call(Maybe::Just["Hello lala"])).to eql "Hello lala"
        expect(Pepe.hello.call(Maybe::Nothing[])).to eql "Hello pepe"

        expect(Pepe.sum_maybe.call(Maybe::Nothing[], 1)).to eql 0
        expect(Pepe.sum_maybe.call(Maybe::Just[10], 1)).to eql 11
      end
    end
  end
end
