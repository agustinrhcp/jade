require 'spec_helper'

require 'jade'
require 'jade/module_loader'

module Jade
  describe 'List' do
    include_context 'with test compiler'

    let(:pepe_source) do
      <<~JADE
        module Pepe exposing(
          strs_to_list, list_length, list_singleton, repeat, is_empty, range,
          maptiply, maptindexply, str_fold
        )

        def strs_to_list(str: String, str2: String) -> List(String)
          [str, str2]
        end

        def list_length(list: List(a)) -> Int
          List.length(list)
        end

        def list_singleton(element: a) -> List(a)
          List.singleton(element)
        end

        def repeat(element: a, times: Int) -> List(a)
          List.repeat(element, times)
        end

        def range(start: Int, end_: Int) -> List(Int)
          List.range(start, end_)
        end

        def is_empty(list: List(a)) -> Bool
          List.is_empty(list)
        end

        def maptiply(list: List(Int)) -> List(Int)
          list
          |> List.map((n) -> { n * 2 })
        end

        def maptindexply(list: List(Int)) -> List(Int)
          list
          |> List.indexed_map((index, n) -> { n * index })
        end

        def str_fold(list: List(String), initial: String) -> String
          list
          |> List.fold(initial, (acc, item) -> { String.concat([acc, item]) })
        end
      JADE
    end

    before do
      test_compiler.require('pepe', pepe_source)
    end

    it 'works' do
      expect(Pepe.strs_to_list.call('1', '2')).to eql ["1", "2"]

      expect(Pepe.list_length.call([])).to eql 0
      expect(Pepe.list_length.call(['1', '2'])).to eql 2
      expect(Pepe.list_length.call([1, 2])).to eql 2

      expect(Pepe.list_singleton.call(0)).to eql [0]

      expect(Pepe.repeat.call(0, 0)).to eql []
      expect(Pepe.repeat.call(0, 2)).to eql [0, 0]

      expect(Pepe.range.call(0, 0)).to eql [0]
      expect(Pepe.range.call(0, 2)).to eql [0, 1, 2]
      expect(Pepe.range.call(6, 3)).to eql []

      expect(Pepe.is_empty.call([])).to be true
      expect(Pepe.is_empty.call([1])).to be false

      expect(Pepe.maptiply.call([1, 2, 3])).to eql [2, 4, 6]

      expect(Pepe.maptindexply.call([1, 2, 3])).to eql [0, 2, 6]

      expect(Pepe.str_fold.call([], "")).to eql ""
      expect(Pepe.str_fold.call(["LalaCoco"], "Pepe")).to eql "PepeLalaCoco"
    end
  end
end
