require 'spec_helper'

require 'jade'
require 'jade/module_loader'

module Jade
  describe 'examples' do
    include_context 'with test compiler'

    let(:pepe_source) do
      <<~JADE
        module Pepe exposing (int_to_r, int_to_r_times_2, int_to_r_times_2_to_r)

        def int_to_r(int: Int) -> Result(Int, String)
          case int
          of 1 -> Ok(1)
          of 2 -> Ok(3)
          of 3 -> Ok(5)
          of _ -> Err("Not 1, 2 or 3")


        def int_to_r_times_2(int: Int) -> Result(Int, String)
          int
            |> int_to_r
            |> Result.map((n) -> { n * 2 })


        def int_to_r_times_2_to_r(int: Int) -> Result(Int, String)
          int
            |> int_to_r
            |> Result.map((n) -> { n * 2 })
            |> Result.and_then(int_to_r)


        def int_to_r_to_maybe(int: Int) -> Maybe(Int)
          int
            |> int_to_r
            |> Result.to_maybe
      JADE
    end

    before do
      test_compiler.require('pepe', pepe_source)
    end

    context 'on_error' do
      let(:on_error_source) do
        <<~JADE
          module OnError exposing (passthrough, recover)

          def recover(r: Result(Int, String)) -> Result(Int, String)
            Result.on_error(r, (e) -> { Ok(0) })


          def passthrough(r: Result(Int, String)) -> Result(Int, String)
            Result.on_error(r, (e) -> { Err(e ++ "!") })
        JADE
      end

      before { test_compiler.require('on_error', on_error_source) }

      it 'passes through Ok unchanged' do
        expect(OnError::Internal.recover.call(Result::Ok[42])).to be_ok(42)
      end

      it 'recovers from Err with a new Ok' do
        expect(OnError::Internal.recover.call(Result::Err["oops"])).to be_ok(0)
      end

      it 'can remap the error' do
        expect(OnError::Internal.passthrough.call(Result::Err["oops"])).to be_err("oops!")
      end
    end

    it 'works' do
      expect(Pepe::Internal.int_to_r.call(1)).to be_ok(1)
      expect(Pepe::Internal.int_to_r.call(2)).to be_ok(3)
      expect(Pepe::Internal.int_to_r.call(3)).to be_ok(5)
      expect(Pepe::Internal.int_to_r.call(4)).to be_err('Not 1, 2 or 3')

      expect(Pepe::Internal.int_to_r_times_2.call(1)).to be_ok(2)
      expect(Pepe::Internal.int_to_r_times_2.call(2)).to be_ok(6)
      expect(Pepe::Internal.int_to_r_times_2.call(4)).to be_err('Not 1, 2 or 3')

      expect(Pepe::Internal.int_to_r_times_2_to_r.call(1)).to be_ok(3)
      expect(Pepe::Internal.int_to_r_times_2_to_r.call(2)).to be_err('Not 1, 2 or 3')

      expect(Pepe::Internal.int_to_r_to_maybe.call(1)).to be_just(1)
      expect(Pepe::Internal.int_to_r_to_maybe.call(2)).to be_just(3)
      expect(Pepe::Internal.int_to_r_to_maybe.call(3)).to be_just(5)
      expect(Pepe::Internal.int_to_r_to_maybe.call(4)).to be_nothing
    end
  end
end
