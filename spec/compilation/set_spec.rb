require 'spec_helper'

require 'jade'

module Jade
  describe 'Set' do
    include_context 'with test compiler'

    let(:source) do
      <<~JADE
        module Pepe exposing (
          add_then_member,
          diff_keys,
          empty_size,
          equal,
          filter_evens,
          fold_sum,
          from_then_to,
          insert_size,
          intersect_keys,
          map_doubles,
          remove_value,
          to_values,
          union_keys,
          unique_via_poly,
        )

        import Set exposing (Set)


        def empty_size -> Int
          Set.size(Set.empty)


        def insert_size -> Int
          Set.singleton(1)
            |> Set.insert(2)
            |> Set.insert(3)
            |> Set.insert(2)
            |> Set.size


        def add_then_member(value: Int) -> Bool
          Set.singleton(1)
            |> Set.insert(2)
            |> Set.member?(value)


        def remove_value(value: Int) -> List(Int)
          Set.singleton(1)
            |> Set.insert(2)
            |> Set.remove(value)
            |> Set.to_list


        def to_values -> List(Int)
          Set.singleton(1)
            |> Set.insert(2)
            |> Set.to_list


        def from_then_to -> List(Int)
          [3, 1, 2, 1, 3]
            |> Set.from_list
            |> Set.to_list


        def map_doubles -> List(Int)
          Set.singleton(1)
            |> Set.insert(2)
            |> Set.insert(3)
            |> Set.map((n) -> { n * 2 })
            |> Set.to_list


        def filter_evens -> List(Int)
          Set.singleton(1)
            |> Set.insert(2)
            |> Set.insert(3)
            |> Set.insert(4)
            |> Set.filter((n) -> { mod(n, 2) == 0 })
            |> Set.to_list


        def fold_sum -> Int
          Set.singleton(1)
            |> Set.insert(2)
            |> Set.insert(3)
            |> Set.fold(0, (v, acc) -> { acc + v })


        def union_keys -> List(Int)
          left = Set.singleton(1) |> Set.insert(2)
          right = Set.singleton(2) |> Set.insert(3)

          Set.union(left, right) |> Set.to_list


        def intersect_keys -> List(Int)
          left = Set.singleton(1)
            |> Set.insert(2)
            |> Set.insert(3)
          right = Set.singleton(2)
            |> Set.insert(3)
            |> Set.insert(4)

          Set.intersect(left, right) |> Set.to_list


        def diff_keys -> List(Int)
          left = Set.singleton(1)
            |> Set.insert(2)
            |> Set.insert(3)
          right = Set.singleton(2)

          Set.diff(left, right) |> Set.to_list


        def equal(a: Set(Int), b: Set(Int)) -> Bool
          set_eq(a, b)


        def set_eq(a: Set(Int), b: Set(Int)) -> Bool
          a == b


        def unique_via_poly(value: Int) -> Bool
          poly_member(Set.singleton(7), value)


        def poly_member(s: Set(a), value: a) -> Bool
          Set.member?(s, value)
      JADE
    end

    before { test_compiler.require('pepe', source) }

    let(:set) { ->(xs) { Jade::Set::Set[xs.each_with_object({}) { |x, h| h[x] = true }] } }

    it 'starts empty' do
      expect(Pepe.empty_size).to eql 0
    end

    it 'sizes after inserts, de-duplicating' do
      expect(Pepe.insert_size).to eql 3
    end

    it 'reports membership' do
      expect(Pepe.add_then_member(1)).to be true
      expect(Pepe.add_then_member(2)).to be true
      expect(Pepe.add_then_member(9)).to be false
    end

    it 'removes a value (no-op when missing)' do
      expect(Pepe.remove_value(1)).to eql [2]
      expect(Pepe.remove_value(9)).to eql [1, 2]
    end

    it 'enumerates values in insertion order' do
      expect(Pepe.to_values).to eql [1, 2]
    end

    it 'rebuilds from a list, dropping duplicates' do
      expect(Pepe::Internal.from_then_to).to eql [3, 1, 2]
    end

    it 'maps over members' do
      expect(Pepe.map_doubles).to eql [2, 4, 6]
    end

    it 'filters by predicate' do
      expect(Pepe.filter_evens).to eql [2, 4]
    end

    it 'folds across the set' do
      expect(Pepe.fold_sum).to eql 6
    end

    it 'unions two sets' do
      expect(Pepe.union_keys).to eql [1, 2, 3]
    end

    it 'intersects two sets' do
      expect(Pepe.intersect_keys).to eql [2, 3]
    end

    it 'diffs two sets' do
      expect(Pepe.diff_keys).to eql [1, 3]
    end

    it 'compares sets structurally (Eq)' do
      a = set.call([1, 2, 3])
      b = set.call([3, 2, 1])
      c = set.call([1, 2, 4])
      expect(Pepe::Internal.equal(a, b)).to be true
      expect(Pepe::Internal.equal(a, c)).to be false
    end

    it 'threads Eq through a polymorphic helper called at a concrete site' do
      expect(Pepe.unique_via_poly(7)).to be true
      expect(Pepe.unique_via_poly(8)).to be false
    end
  end
end
