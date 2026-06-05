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
          indices_only,
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


        def empty?(list: List(a)) -> Bool
          List.empty?(list)
        end


        def maptiply(list: List(Int)) -> List(Int)
          list |> List.map((n) -> { n * 2 })
        end


        def maptindexply(list: List(Int)) -> List(Int)
          list |> List.indexed_map((index, n) -> { n * index })
        end


        def indices_only(list: List(Int)) -> List(Int)
          list |> List.indexed_map((index, _) -> { index })
        end


        def str_fold(list: List(String), initial: String) -> String
          list |> List.fold(initial, (acc, item) -> { String.concat([acc, item]) })
        end
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
      expect(Pepe.indices_only([10, 20, 30])).to eql [0, 1, 2]

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
          end


          def sort_floats(list: List(Float)) -> List(Float)
            List.sort(list)
          end


          def sort_strings(list: List(String)) -> List(String)
            List.sort(list)
          end


          def sort_by_neg(list: List(Int)) -> List(Int)
            list |> List.sort_by((n) -> { 0 - n })
          end


          def sort_by_str_len(list: List(String)) -> List(String)
            list |> List.sort_by(String.length)
          end
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
              in IS(i, s) then Encode.tuple(Encode.int, Encode.string, (i, s))
              end
            }
          end


          implements Decodable(IS) with
            decoder: -> { Decode.tuple(Decode.int, Decode.string)
              |> Decode.map((t) -> {
              case t
              in (i, s) then IS(i, s)
              end
            }) }
          end


          implements Encodable(Buckets) with
            encoder: (b) -> {
              case b
              in Buckets(l, r)
                Encode.tuple(Encode.list(Encode.int, _), Encode.list(Encode.int, _), (l, r))
              end
            }
          end


          implements Encodable(Unzipped) with
            encoder: (u) -> {
              case u
              in Unzipped(l, r)
                Encode.tuple(
                  Encode.list(Encode.int, _),
                  Encode.list(Encode.string, _),
                  (l, r),
                )
              end
            }
          end


          def any_neg(list: List(Int)) -> Bool
            list |> List.any?((n) -> { n < 0 })
          end


          def all_pos(list: List(Int)) -> Bool
            list |> List.all?((n) -> { n > 0 })
          end


          def first_even(list: List(Int)) -> Maybe(Int)
            list |> List.find((n) -> { mod(n, 2) == 0 })
          end


          def evens_doubled(list: List(Int)) -> List(Int)
            list |> List.filter_map((n) -> {
              mod(n, 2) == 0 ? Just(n * 2) : Nothing
            })
          end


          def tk(list: List(Int), n: Int) -> List(Int)
            List.take(list, n)
          end


          def dr(list: List(Int), n: Int) -> List(Int)
            List.drop(list, n)
          end


          def part_evens(list: List(Int)) -> Buckets
            case list |> List.partition((n) -> { mod(n, 2) == 0 })
            in (pass, rest) then Buckets(pass, rest)
            end
          end


          def cat(lists: List(List(Int))) -> List(Int)
            List.concat(lists)
          end


          def zip_pairs(a: List(Int), b: List(String)) -> List(IS)
            List.zip(a, b)
              |> List.map((t) -> {
            case t
            in (i, s) then IS(i, s)
            end
          })
          end


          def unzip_pairs(pairs: List(IS)) -> Unzipped
            case pairs
              |> List.map((p) -> {
              case p
              in IS(i, s) then (i, s)
              end
            })
              |> List.unzip
            in (a, b) then Unzipped(a, b)
            end
          end


          def has_two?(list: List(Int)) -> Bool
            List.member?(list, 2)
          end


          def max_ints(list: List(Int)) -> Maybe(Int)
            List.maximum(list)
          end


          def min_ints(list: List(Int)) -> Maybe(Int)
            List.minimum(list)
          end


          def max_strs(list: List(String)) -> Maybe(String)
            List.maximum(list)
          end


          def min_strs(list: List(String)) -> Maybe(String)
            List.minimum(list)
          end
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
          end
        JADE
      end

      it 'rejects List.sort_with at compile time' do
        expect { test_compiler.require('sneaky', source) }
          .to raise_error(CompilationError, /sort_with/)
      end
    end
  end
end
