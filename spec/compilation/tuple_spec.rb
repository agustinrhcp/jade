require 'spec_helper'

require 'jade'
require 'jade/module_loader'

module Jade
  describe 'Tuple' do
    include_context 'with test compiler'

    let(:pepe_source) do
      <<~JADE
        module Pepe exposing(
          make_pair, get_first, get_second, swap, pattern_matching
        )

        def make_pair(a: Int, b: String) -> (Int, String)
          (a, b)
        end

        def get_first(pair: (Int, String)) -> Int
          Tuple.first(pair)
        end

        def get_second(pair: (Int, String)) -> String
          Tuple.second(pair)
        end

        def swap(pair: (Int, String)) -> (String, Int)
          (Tuple.second(pair), Tuple.first(pair))
        end

        def pattern_matching(int: Int, str: String) -> Int
          case (int, str)
          of (1, "1") then 1
          of (2, "2") then 2
          of _ then 0
          end
        end
      JADE
    end

    before do
      test_compiler.require('pepe', pepe_source)
    end

    it 'works' do
      expect(Pepe.make_pair.call(1, "hello")).to eql Tuple::Tuple2[1, "hello"]
      expect(Pepe.get_first.call(Tuple::Tuple2[1, "hello"])).to eql 1
      expect(Pepe.get_second.call(Tuple::Tuple2[1, "hello"])).to eql "hello"
      expect(Pepe.swap.call(Tuple::Tuple2[1, "hello"])).to eql Tuple::Tuple2["hello", 1]
      expect(Pepe.pattern_matching.call(1, "1")).to eql 1
      expect(Pepe.pattern_matching.call(3, "3")).to eql 0
    end
  end
end
