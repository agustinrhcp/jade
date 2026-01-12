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
          of 1 then Ok(1)
          of 2 then Ok(3)
          of 3 then Ok(5)
          of _ then Err("Not 1, 2 or 3")
          end
        end

        def int_to_r_times_2(int: Int) -> Result(Int, String)
          int |> int_to_r |> Result.map((n) -> { n * 2 })
        end

        def int_to_r_times_2_to_r(int: Int) -> Result(Int, String)
          int
            |> int_to_r
            |> Result.map((n) -> { n * 2 })
            |> Result.and_then(int_to_r)
        end

        def int_to_r_to_maybe(int: Int) -> Maybe(Int)
          int
          |> int_to_r
          |> Result.to_maybe
        end
      JADE
    end

    before do
      test_compiler.require('pepe', pepe_source)
    end

    it 'works' do
      expect(Pepe.int_to_r.call(1)).to eql Result::Ok[1]
      expect(Pepe.int_to_r.call(2)).to eql Result::Ok[3]
      expect(Pepe.int_to_r.call(3)).to eql Result::Ok[5]
      expect(Pepe.int_to_r.call(4)).to eql Result::Err['Not 1, 2 or 3']

      expect(Pepe.int_to_r_times_2.call(1)).to eql Result::Ok[2]
      expect(Pepe.int_to_r_times_2.call(2)).to eql Result::Ok[6]
      expect(Pepe.int_to_r_times_2.call(4)).to eql Result::Err['Not 1, 2 or 3']

      expect(Pepe.int_to_r_times_2_to_r.call(1)).to eql Result::Ok[3]
      expect(Pepe.int_to_r_times_2_to_r.call(2)).to eql Result::Err['Not 1, 2 or 3']

      expect(Pepe.int_to_r_to_maybe.call(1)).to eql Maybe::Just[1]
      expect(Pepe.int_to_r_to_maybe.call(2)).to eql Maybe::Just[3]
      expect(Pepe.int_to_r_to_maybe.call(3)).to eql Maybe::Just[5]
      expect(Pepe.int_to_r_to_maybe.call(4)).to eql Maybe::Nothing[]
    end
  end
end
