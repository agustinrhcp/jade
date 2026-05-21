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
          Dict.size(Dict.empty())


        def insert_size -> Int
          Dict.singleton("a", 1)
            |> Dict.insert("b", 2)
            |> Dict.insert("c", 3)
            |> Dict.size


        def add_then_get(key: String) -> Maybe(Int)
          Dict.singleton("a", 1)
            |> Dict.insert("b", 2)
            |> Dict.get(key)


        def missing(key: String) -> Bool
          Dict.singleton("a", 1) |> Dict.member(key)


        def remove_key(key: String) -> List(String)
          Dict.singleton("a", 1)
            |> Dict.insert("b", 2)
            |> Dict.remove(key)
            |> Dict.keys


        def keys_of -> List(String)
          Dict.singleton("a", 1)
            |> Dict.insert("b", 2)
            |> Dict.keys


        def values_of -> List(Int)
          Dict.singleton("a", 1)
            |> Dict.insert("b", 2)
            |> Dict.values


        def to_pairs -> List((String, Int))
          Dict.singleton("a", 1)
            |> Dict.insert("b", 2)
            |> Dict.to_list


        def rebuild -> List((String, Int))
          [("x", 10), ("y", 20)]
            |> Dict.from_list
            |> Dict.to_list


        def rename_value(key: String) -> Maybe(String)
          Dict.singleton("a", 1)
            |> Dict.insert("b", 2)
            |> Dict.map((_k, v) -> { String.from_int(v) })
            |> Dict.get(key)


        def keep_evens -> List(String)
          Dict.singleton("a", 1)
            |> Dict.insert("b", 2)
            |> Dict.insert("c", 3)
            |> Dict.insert("d", 4)
            |> Dict.filter((_k, v) -> { mod(v, 2) == 0 })
            |> Dict.keys


        def fold_sum -> Int
          Dict.singleton("a", 1)
            |> Dict.insert("b", 2)
            |> Dict.insert("c", 3)
            |> Dict.fold(0, (_k, v, acc) -> { acc + v })


        def union_left -> Maybe(Int)
          left = Dict.singleton("a", 1)
          right = Dict.singleton("a", 99) |> Dict.insert("b", 2)

          Dict.union(left, right) |> Dict.get("a")


        def merge_sum(key: String) -> Maybe(Int)
          left = Dict.singleton("a", 1) |> Dict.insert("b", 10)
          right = Dict.singleton("a", 2) |> Dict.insert("c", 30)

          Dict.merge(left, right, (l, r) -> { l + r }) |> Dict.get(key)


        def counts(words: List(String)) -> Dict(String, Int)
          List.fold(words, Dict.empty(), (acc, word) -> { bump(acc, word) })


        def bump(acc: Dict(String, Int), word: String) -> Dict(String, Int)
          Dict.update(acc, word, (m) -> { incr(m) })


        def incr(m: Maybe(Int)) -> Maybe(Int)
          case m
          of Just(n) -> Just(n + 1)
          of Nothing -> Just(1)


        def equal(a: Dict(String, Int), b: Dict(String, Int)) -> Bool
          dict_eq(a, b)


        def dict_eq(a: Dict(String, Int), b: Dict(String, Int)) -> Bool
          a == b


        def lookup_via_poly(key: String) -> Maybe(Int)
          poly_get(Dict.singleton("hit", 7), key)


        def poly_get(d: Dict(k, v), key: k) -> Maybe(v)
          Dict.get(d, key)
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
      expect(Pepe::Internal.to_pairs.call).to eql [
        Jade::Tuple::Tuple2['a', 1],
        Jade::Tuple::Tuple2['b', 2],
      ]
    end

    it 'rebuilds from a list of pairs (last write wins)' do
      expect(Pepe::Internal.rebuild.call).to eql [
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
      result = Pepe::Internal.counts.call(%w[a b a c a b])
      expect(result.hash).to eql({ 'a' => 3, 'b' => 2, 'c' => 1 })
    end

    it 'compares dicts structurally (Eq)' do
      a = dict.call({ 'x' => 1, 'y' => 2 })
      b = dict.call({ 'y' => 2, 'x' => 1 })
      c = dict.call({ 'x' => 1, 'y' => 3 })
      expect(Pepe::Internal.equal.call(a, b)).to be true
      expect(Pepe::Internal.equal.call(a, c)).to be false
    end

    it 'threads Eq through a polymorphic helper called at a concrete site' do
      expect(Pepe.lookup_via_poly('hit')).to eql 7
      expect(Pepe.lookup_via_poly('miss')).to be_nil
    end
  end
end
