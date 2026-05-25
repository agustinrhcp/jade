require 'spec_helper'

require 'jade'
require 'jade/module_loader'

module Jade
  describe 'List' do
    include_context 'with test compiler'

    let(:pepe_source) do
      <<~JADE
        module Pepe exposing (
          empty?,
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


        def empty?(list: List(a)) -> Bool
          List.empty?(list)


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

      expect(Pepe::Internal.list_length([])).to eql 0
      expect(Pepe::Internal.list_length(['1', '2'])).to eql 2
      expect(Pepe::Internal.list_length([1, 2])).to eql 2

      expect(Pepe::Internal.list_singleton(0)).to eql [0]

      expect(Pepe::Internal.repeat(0, 0)).to eql []
      expect(Pepe::Internal.repeat(0, 2)).to eql [0, 0]

      expect(Pepe.range(0, 0)).to eql [0]
      expect(Pepe.range(0, 2)).to eql [0, 1, 2]
      expect(Pepe.range(6, 3)).to eql []

      expect(Pepe::Internal.empty?([])).to be true
      expect(Pepe::Internal.empty?([1])).to be false

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

    context 'phase-1 additions' do
      let(:source) do
        <<~JADE
          module L exposing (
            all_pos,
            any_neg,
            cat,
            dr,
            evens_doubled,
            first_even,
            has_two?,
            max_ints,
            max_strs,
            min_ints,
            min_strs,
            part_evens,
            tk,
            unzip_pairs,
            zip_pairs,
          )

          import Encode exposing (Encodable)
          import Decode exposing (Decodable)


          type IS = IS(Int, String)


          type Buckets = Buckets(List(Int), List(Int))


          type Unzipped = Unzipped(List(Int), List(String))


          implements Encodable(IS) with
            encoder: (p) -> {
              case p
              of IS(i, s) -> Encode.tuple(Encode.int, Encode.string, (i, s))
            }


          implements Decodable(IS) with
            decoder: -> { Decode.tuple(Decode.int, Decode.string) |> Decode.map((t) -> {
              case t
              of (i, s) -> IS(i, s)
            }) }


          implements Encodable(Buckets) with
            encoder: (b) -> {
              case b
              of Buckets(l, r) ->
                Encode.tuple(Encode.list(Encode.int, _), Encode.list(Encode.int, _), (l, r))
            }


          implements Encodable(Unzipped) with
            encoder: (u) -> {
              case u
              of Unzipped(l, r) ->
                Encode.tuple(
                  Encode.list(Encode.int, _),
                  Encode.list(Encode.string, _),
                  (l, r),
                )
            }


          def any_neg(list: List(Int)) -> Bool
            list |> List.any?((n) -> { n < 0 })


          def all_pos(list: List(Int)) -> Bool
            list |> List.all?((n) -> { n > 0 })


          def first_even(list: List(Int)) -> Maybe(Int)
            list |> List.find((n) -> { mod(n, 2) == 0 })


          def evens_doubled(list: List(Int)) -> List(Int)
            list |> List.filter_map((n) -> {
              if mod(n, 2) == 0 then Just(n * 2) else Nothing
            })


          def tk(list: List(Int), n: Int) -> List(Int)
            List.take(list, n)


          def dr(list: List(Int), n: Int) -> List(Int)
            List.drop(list, n)


          def part_evens(list: List(Int)) -> Buckets
            case list |> List.partition((n) -> { mod(n, 2) == 0 })
            of (pass, rest) -> Buckets(pass, rest)


          def cat(lists: List(List(Int))) -> List(Int)
            List.concat(lists)


          def zip_pairs(a: List(Int), b: List(String)) -> List(IS)
            List.zip(a, b) |> List.map((t) -> {
              case t
              of (i, s) -> IS(i, s)
            })


          def unzip_pairs(pairs: List(IS)) -> Unzipped
            case pairs
              |> List.map((p) -> {
              case p
              of IS(i, s) -> (i, s)
            })
              |> List.unzip
            of (a, b) -> Unzipped(a, b)


          def has_two?(list: List(Int)) -> Bool
            List.member?(list, 2)


          def max_ints(list: List(Int)) -> Maybe(Int)
            List.maximum(list)


          def min_ints(list: List(Int)) -> Maybe(Int)
            List.minimum(list)


          def max_strs(list: List(String)) -> Maybe(String)
            List.maximum(list)


          def min_strs(list: List(String)) -> Maybe(String)
            List.minimum(list)
        JADE
      end

      before { test_compiler.require('l', source) }

      it 'any / all' do
        expect(L.any_neg([1, 2, 3])).to be false
        expect(L.any_neg([1, -2, 3])).to be true
        expect(L.all_pos([1, 2, 3])).to be true
        expect(L.all_pos([1, 0, 3])).to be false
        expect(L.all_pos([])).to be true
      end

      it 'find returns Maybe' do
        expect(L.first_even([1, 3, 4, 6])).to eql 4
        expect(L.first_even([1, 3, 5])).to be_nil
      end

      it 'filter_map keeps Just values' do
        expect(L.evens_doubled([1, 2, 3, 4])).to eql [4, 8]
        expect(L.evens_doubled([])).to eql []
      end

      it 'take / drop clamp at 0' do
        expect(L.tk([1, 2, 3, 4], 2)).to eql [1, 2]
        expect(L.tk([1, 2, 3], 10)).to eql [1, 2, 3]
        expect(L.tk([1, 2, 3], 0)).to eql []
        expect(L.tk([1, 2, 3], -1)).to eql []
        expect(L.dr([1, 2, 3, 4], 2)).to eql [3, 4]
        expect(L.dr([1, 2, 3], 10)).to eql []
        expect(L.dr([1, 2, 3], -1)).to eql [1, 2, 3]
      end

      it 'partition splits on predicate' do
        expect(L.part_evens([1, 2, 3, 4])).to eql [[2, 4], [1, 3]]
      end

      it 'concat flattens one level' do
        expect(L.cat([[1, 2], [3], [], [4]])).to eql [1, 2, 3, 4]
        expect(L.cat([])).to eql []
      end

      it 'zip truncates to shorter list' do
        expect(L.zip_pairs([1, 2, 3], ['a', 'b'])).to eql [[1, 'a'], [2, 'b']]
      end

      it 'unzip splits pairs into two lists' do
        pairs = L.zip_pairs([1, 2, 3], ['a', 'b', 'c'])
        expect(L.unzip_pairs(pairs)).to eql [[1, 2, 3], ['a', 'b', 'c']]
      end

      it 'member uses Eq' do
        expect(L.has_two?([1, 2, 3])).to be true
        expect(L.has_two?([1, 3])).to be false
        expect(L.has_two?([])).to be false
      end

      it 'maximum / minimum return Nothing on empty' do
        expect(L.max_ints([3, 1, 4, 1, 5])).to eql 5
        expect(L.min_ints([3, 1, 4, 1, 5])).to eql 1
        expect(L.max_ints([])).to be_nil
        expect(L.min_ints([])).to be_nil
        expect(L.max_strs(['banana', 'apple', 'cherry'])).to eql 'cherry'
        expect(L.min_strs(['banana', 'apple', 'cherry'])).to eql 'apple'
      end
    end

    context 'private helpers are hidden from user code' do
      let(:source) do
        <<~JADE
          module Sneaky exposing (boom)

          def boom(list: List(Int)) -> List(Int)
            List.sort_with(list, int_compare)
        JADE
      end

      it 'rejects List.sort_with at compile time' do
        expect { test_compiler.require('sneaky', source) }
          .to raise_error(CompilationError, /sort_with/)
      end
    end
  end
end
