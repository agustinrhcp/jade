require 'spec_helper'

require 'jade'
require 'jade/module_loader'

module Jade
  describe 'examples' do
    include_context 'with test compiler'

    let(:pepe_source) do
      <<~JADE
        module Pepe exposing (and_then_test, hello, sum_maybe)

        def hello(maybe: Maybe(String)) -> String
          Maybe.with_default(maybe, "Hello pepe")
        end


        def sum_maybe(maybe: Maybe(Int), n: Int) -> Int
          Maybe.with_default(Maybe.map(maybe, (m) -> { m + n }), 0)
        end


        def and_then_test(n: Maybe(Int)) -> Maybe(String)
          Maybe.and_then(
            n,
            (int) -> {
              case int
              in 1 then Just("ONE")
              else Nothing
              end
            },
          )
        end
      JADE
    end

    it 'works' do
      test_compiler.require('pepe', pepe_source)

      expect(Pepe.hello("Hello lala")).to eql "Hello lala"
      expect(Pepe.hello(nil)).to eql "Hello pepe"

      expect(Pepe.sum_maybe(nil, 1)).to eql 0
      expect(Pepe.sum_maybe(10, 1)).to eql 11

      expect(Pepe.and_then_test(nil)).to be_nil
      expect(Pepe.and_then_test(2)).to be_nil
      expect(Pepe.and_then_test(1)).to eql 'ONE'
    end

    context 'without type arguments' do
      let(:pepe_source) do
        <<~JADE
          module Pepe exposing (nott)

          def nott -> Maybe
            Nothing
          end
        JADE
      end

      it 'fails' do
        expect { test_compiler.require('pepe', pepe_source) }
          .to raise_error(CompilationError, /`Maybe` type needs 1 argument but got 0/)
      end
    end
  end
end
