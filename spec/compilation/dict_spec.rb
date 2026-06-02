require 'spec_helper'

require 'jade'

module Jade
  describe 'Dict' do
    include_context 'with test compiler'

    let(:source) do
      <<~JADE
        module Pepe exposing (
          add_then_get,
          counts,
          empty_size,
          equal,
          fold_sum,
          insert_size,
          keep_evens,
          keys_of,
          lookup_via_poly,
          merge_sum,
          missing,
          rebuild,
          remove_key,
          rename_value,
          to_pairs,
          union_left,
          values_of,
        )

        import Dict exposing (Dict)


        def empty_size -> Int
          Dict.size(Dict.empty)
        end


        def insert_size -> Int
          Dict.singleton("a", 1)
            |> Dict.insert("b", 2)
            |> Dict.insert("c", 3)
            |> Dict.size
        end


        def add_then_get(key: String) -> Maybe(Int)
          Dict.singleton("a", 1)
            |> Dict.insert("b", 2)
            |> Dict.get(key)
        end


        def missing(key: String) -> Bool
          Dict.singleton("a", 1) |> Dict.member?(key)
        end


        def remove_key(key: String) -> List(String)
          Dict.singleton("a", 1)
            |> Dict.insert("b", 2)
            |> Dict.remove(key)
            |> Dict.keys
        end


        def keys_of -> List(String)
          Dict.singleton("a", 1)
            |> Dict.insert("b", 2)
            |> Dict.keys
        end


        def values_of -> List(Int)
          Dict.singleton("a", 1)
            |> Dict.insert("b", 2)
            |> Dict.values
        end


        def to_pairs -> List((String, Int))
          Dict.singleton("a", 1)
            |> Dict.insert("b", 2)
            |> Dict.to_list
        end


        def rebuild -> List((String, Int))
          [("x", 10), ("y", 20)]
            |> Dict.from_list
            |> Dict.to_list
        end


        def rename_value(key: String) -> Maybe(String)
          Dict.singleton("a", 1)
            |> Dict.insert("b", 2)
            |> Dict.map((_k, v) -> { String.from_int(v) })
            |> Dict.get(key)
        end


        def keep_evens -> List(String)
          Dict.singleton("a", 1)
            |> Dict.insert("b", 2)
            |> Dict.insert("c", 3)
            |> Dict.insert("d", 4)
            |> Dict.filter((_k, v) -> { mod(v, 2) == 0 })
            |> Dict.keys
        end


        def fold_sum -> Int
          Dict.singleton("a", 1)
            |> Dict.insert("b", 2)
            |> Dict.insert("c", 3)
            |> Dict.fold(0, (_k, v, acc) -> { acc + v })
        end


        def union_left -> Maybe(Int)
          left = Dict.singleton("a", 1)
          right = Dict.singleton("a", 99) |> Dict.insert("b", 2)
          Dict.union(left, right) |> Dict.get("a")
        end


        def merge_sum(key: String) -> Maybe(Int)
          left = Dict.singleton("a", 1) |> Dict.insert("b", 10)
          right = Dict.singleton("a", 2) |> Dict.insert("c", 30)
          Dict.merge(left, right, (l, r) -> { l + r }) |> Dict.get(key)
        end


        def counts(words: List(String)) -> Dict(String, Int)
          List.fold(words, Dict.empty, (acc, word) -> { bump(acc, word) })
        end


        def bump(acc: Dict(String, Int), word: String) -> Dict(String, Int)
          Dict.update(acc, word, (m) -> { incr(m) })
        end


        def incr(m: Maybe(Int)) -> Maybe(Int)
          case m
          in Just(n) then Just(n + 1)
          in Nothing then Just(1)
          end
        end


        def equal(a: Dict(String, Int), b: Dict(String, Int)) -> Bool
          dict_eq(a, b)
        end


        def dict_eq(a: Dict(String, Int), b: Dict(String, Int)) -> Bool
          a == b
        end


        def lookup_via_poly(key: String) -> Maybe(Int)
          poly_get(Dict.singleton("hit", 7), key)
        end


        def poly_get(d: Dict(k, v), key: k) -> Maybe(v)
          Dict.get(d, key)
        end
      JADE
    end

    before { test_compiler.require('pepe', source) }

    let(:dict) { ->(h) { Jade::Dict::Dict[h] } }

    it 'starts empty' do
      expect(Pepe.empty_size).to eql 0
    end

    it 'sizes after inserts' do
      expect(Pepe.insert_size).to eql 3
    end

    it 'gets a value (or Nothing)' do
      expect(Pepe.add_then_get('a')).to eql 1
      expect(Pepe.add_then_get('b')).to eql 2
      expect(Pepe.add_then_get('z')).to be_nil
    end

    it 'reports membership' do
      expect(Pepe.missing('a')).to be true
      expect(Pepe.missing('z')).to be false
    end

    it 'removes a key (no-op when missing)' do
      expect(Pepe.remove_key('a')).to eql ['b']
      expect(Pepe.remove_key('z')).to eql ['a', 'b']
    end

    it 'enumerates keys/values/pairs in insertion order' do
      expect(Pepe.keys_of).to eql ['a', 'b']
      expect(Pepe.values_of).to eql [1, 2]
      expect(Pepe::Internal.to_pairs).to eql [
        Jade::Tuple::Tuple2['a', 1],
        Jade::Tuple::Tuple2['b', 2],
      ]
    end

    it 'rebuilds from a list of pairs (last write wins)' do
      expect(Pepe::Internal.rebuild).to eql [
        Jade::Tuple::Tuple2['x', 10],
        Jade::Tuple::Tuple2['y', 20],
      ]
    end

    it 'maps values, keeping keys' do
      expect(Pepe.rename_value('a')).to eql '1'
      expect(Pepe.rename_value('b')).to eql '2'
    end

    it 'filters by predicate' do
      expect(Pepe.keep_evens).to eql ['b', 'd']
    end

    it 'folds across the dict' do
      expect(Pepe.fold_sum).to eql 6
    end

    it 'union is left-biased' do
      expect(Pepe.union_left).to eql 1
    end

    it 'merge combines overlapping keys with the supplied fn' do
      expect(Pepe.merge_sum('a')).to eql 3
      expect(Pepe.merge_sum('b')).to eql 10
      expect(Pepe.merge_sum('c')).to eql 30
    end

    it 'counts a stream of words via update + fold' do
      result = Pepe::Internal.counts(%w[a b a c a b])
      expect(result.hash).to eql({ 'a' => 3, 'b' => 2, 'c' => 1 })
    end

    it 'compares dicts structurally (Eq)' do
      a = dict.call({ 'x' => 1, 'y' => 2 })
      b = dict.call({ 'y' => 2, 'x' => 1 })
      c = dict.call({ 'x' => 1, 'y' => 3 })
      expect(Pepe::Internal.equal(a, b)).to be true
      expect(Pepe::Internal.equal(a, c)).to be false
    end

    it 'threads Eq through a polymorphic helper called at a concrete site' do
      expect(Pepe.lookup_via_poly('hit')).to eql 7
      expect(Pepe.lookup_via_poly('miss')).to be_nil
    end
  end

  describe 'Dict at the Ruby boundary' do
    include_context 'with test compiler'

    let(:source) do
      <<~JADE
        module Pepe exposing (round_trip, size_of, sum_values)

        import Dict exposing (Dict)


        def size_of(d: Dict(String, Int)) -> Int
          Dict.size(d)
        end


        def sum_values(d: Dict(String, Int)) -> Int
          Dict.fold(d, 0, (_k, v, acc) -> { acc + v })
        end


        def round_trip(d: Dict(String, Int)) -> Dict(String, Int)
          d
        end
      JADE
    end

    before { test_compiler.require('pepe', source) }

    it 'accepts a Ruby Hash for Dict(String, Int) args' do
      expect(Pepe.size_of({})).to eql 0
      expect(Pepe.size_of({ 'a' => 1, 'b' => 2 })).to eql 2
    end

    it 'reads values out of the decoded Dict' do
      expect(Pepe.sum_values({ 'a' => 10, 'b' => 32 })).to eql 42
    end

    it 'returns list-of-pairs on the encode side' do
      expect(Pepe.round_trip({ 'a' => 1 })).to eql [['a', 1]]
    end

    it 'also accepts a list of [k, v] pairs (Encode.dict round-trip shape)' do
      expect(Pepe.size_of([['a', 1], ['b', 2]])).to eql 2
    end
  end
end
