require 'spec_helper'

require 'jade'
require 'jade/module_loader'

module Jade
  describe 'List' do
    include_context 'with test compiler'

    let(:pepe_source) do
      <<~JADE
        module Pepe exposing (
          is_empty,
          list_length,
          list_singleton,
          maptindexply,
          maptiply,
          range,
          repeat,
          str_fold,
          strs_to_list,
        )

        def strs_to_list(str: String, str2: String) -> List(String)
          [str, str2]


        def list_length(list: List(a)) -> Int
          List.length(list)


        def list_singleton(element: a) -> List(a)
          List.singleton(element)


        def repeat(element: a, times: Int) -> List(a)
          List.repeat(element, times)


        def range(start: Int, end_: Int) -> List(Int)
          List.range(start, end_)


        def is_empty(list: List(a)) -> Bool
          List.is_empty(list)


        def maptiply(list: List(Int)) -> List(Int)
          list |> List.map((n) -> { n * 2 })


        def maptindexply(list: List(Int)) -> List(Int)
          list |> List.indexed_map((index, n) -> { n * index })


        def str_fold(list: List(String), initial: String) -> String
          list |> List.fold(initial, (acc, item) -> { String.concat([acc, item]) })
      JADE
    end

    before do
      test_compiler.require('pepe', pepe_source)
    end

    it 'works' do
      expect(Pepe.strs_to_list('1', '2')).to eql ["1", "2"]

      expect(Pepe::Internal.list_length.call([])).to eql 0
      expect(Pepe::Internal.list_length.call(['1', '2'])).to eql 2
      expect(Pepe::Internal.list_length.call([1, 2])).to eql 2

      expect(Pepe::Internal.list_singleton.call(0)).to eql [0]

      expect(Pepe::Internal.repeat.call(0, 0)).to eql []
      expect(Pepe::Internal.repeat.call(0, 2)).to eql [0, 0]

      expect(Pepe.range(0, 0)).to eql [0]
      expect(Pepe.range(0, 2)).to eql [0, 1, 2]
      expect(Pepe.range(6, 3)).to eql []

      expect(Pepe::Internal.is_empty.call([])).to be true
      expect(Pepe::Internal.is_empty.call([1])).to be false

      expect(Pepe.maptiply([1, 2, 3])).to eql [2, 4, 6]

      expect(Pepe.maptindexply([1, 2, 3])).to eql [0, 2, 6]

      expect(Pepe.str_fold([], "")).to eql ""
      expect(Pepe.str_fold(["LalaCoco"], "Pepe")).to eql "PepeLalaCoco"
    end

    context 'sort and sort_by' do
      let(:source) do
        <<~JADE
          module SortTest exposing (
            sort_by_neg,
            sort_by_str_len,
            sort_floats,
            sort_ints,
            sort_strings,
          )

          def sort_ints(list: List(Int)) -> List(Int)
            List.sort(list)


          def sort_floats(list: List(Float)) -> List(Float)
            List.sort(list)


          def sort_strings(list: List(String)) -> List(String)
            List.sort(list)


          def sort_by_neg(list: List(Int)) -> List(Int)
            list |> List.sort_by((n) -> { 0 - n })


          def sort_by_str_len(list: List(String)) -> List(String)
            list |> List.sort_by(String.length)
        JADE
      end

      before { test_compiler.require('sort_test', source) }

      it 'sorts ints, floats, strings and supports sort_by' do
        expect(SortTest.sort_ints([3, 1, 2])).to eql [1, 2, 3]
        expect(SortTest.sort_ints([])).to eql []
        expect(SortTest.sort_floats([2.5, 1.1, 3.3])).to eql [1.1, 2.5, 3.3]
        expect(SortTest.sort_strings(['c', 'a', 'b'])).to eql ['a', 'b', 'c']
        expect(SortTest.sort_by_neg([1, 3, 2])).to eql [3, 2, 1]
        expect(SortTest.sort_by_str_len(['ccc', 'a', 'bb'])).to eql ['a', 'bb', 'ccc']
      end
    end
  end
end
