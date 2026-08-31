require 'spec_helper'

require 'jade'
require 'jade/module_loader'

module Jade
  # Jade values do not change. A caller that hands over an array and keeps
  # pushing to it would otherwise be writing into one Jade already took.
  describe 'a value crossing from Ruby' do
    include_context 'with test compiler'

    before do
      test_compiler.require(<<~JADE.strip)
        module Echo exposing (Row(..), rows, size, values)

        struct Row = { n: Int }


        def values(xs: List(Int)) -> List(Int)
          xs
        end


        def rows(rs: List(Row)) -> List(Row)
          rs
        end


        def size(xs: List(Int)) -> Int
          List.length(xs)
        end
      JADE
    end

    it 'is not the array the caller still holds' do
      xs = [1, 2, 3]

      expect(Echo.values(xs)).not_to be xs
    end

    it 'does not change when the caller pushes afterwards' do
      xs = [1, 2, 3]
      taken = Echo.values(xs)
      xs << 4

      expect(taken).to eq [1, 2, 3]
    end

    it 'copies a list of structs too, which it already did' do
      rows = [{ 'n' => 1 }]

      expect(Echo.rows(rows)).not_to be rows
    end

    it 'still sees what it was given' do
      expect(Echo.size([1, 2, 3])).to eq 3
    end
  end
end
