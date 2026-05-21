require 'jade/stdlib/intrinsics'

module Jade
  module Stdlib
    module Dict
      extend Intrinsics

      import Basics
      import Maybe
      import List
      import Tuple

      union :Dict, 'k', 'v'

      native_type :Dict, Jade::Dict::Dict

      implementation('Eq', 'Dict', '(==)' => 'dict_eq')

      function(
        :empty,
        {},
        'Dict(k, v)',
      ) { Jade::Dict::Dict[{}] }

      function(
        :singleton,
        { key: 'k', value: 'v' },
        'Dict(k, v)',
        constraints: [['Basics.Eq', 'k']],
      ) { |key, value| Jade::Dict::Dict[{ key => value }] }

      function(
        :is_empty,
        { dict: 'Dict(k, v)' },
        'Bool',
      ) { it.hash.empty? }

      function(
        :size,
        { dict: 'Dict(k, v)' },
        'Int',
      ) { it.hash.size }

      function(
        :get,
        { dict: 'Dict(k, v)', key: 'k' },
        'Maybe(v)',
        constraints: [['Basics.Eq', 'k']],
      ) do |dict, key|
        dict.hash.key?(key) \
          ? Jade::Maybe::Just[dict.hash[key]]
          : Jade::Maybe::Nothing[]
      end

      function(
        :member,
        { dict: 'Dict(k, v)', key: 'k' },
        'Bool',
        constraints: [['Basics.Eq', 'k']],
      ) { |dict, key| dict.hash.key?(key) }

      function(
        :insert,
        { dict: 'Dict(k, v)', key: 'k', value: 'v' },
        'Dict(k, v)',
        constraints: [['Basics.Eq', 'k']],
      ) { |dict, key, value| Jade::Dict::Dict[dict.hash.merge(key => value)] }

      function(
        :remove,
        { dict: 'Dict(k, v)', key: 'k' },
        'Dict(k, v)',
        constraints: [['Basics.Eq', 'k']],
      ) do |dict, key|
        dict.hash.key?(key) \
          ? Jade::Dict::Dict[dict.hash.except(key)]
          : dict
      end

      function(
        :update,
        { dict: 'Dict(k, v)', key: 'k', fn: 'Maybe(v) -> Maybe(v)' },
        'Dict(k, v)',
        constraints: [['Basics.Eq', 'k']],
      ) do |dict, key, fn|
        current = dict.hash.key?(key) ? Jade::Maybe::Just[dict.hash[key]] : Jade::Maybe::Nothing[]
        case fn.call(current)
        in Jade::Maybe::Just[v] then Jade::Dict::Dict[dict.hash.merge(key => v)]
        in Jade::Maybe::Nothing then Jade::Dict::Dict[dict.hash.except(key)]
        end
      end

      function(
        :keys,
        { dict: 'Dict(k, v)' },
        'List(k)',
      ) { it.hash.keys }

      function(
        :values,
        { dict: 'Dict(k, v)' },
        'List(v)',
      ) { it.hash.values }

      function(
        :to_list,
        { dict: 'Dict(k, v)' },
        'List(Tuple2(k, v))',
      ) { it.hash.map { |k, v| Jade::Tuple::Tuple2[k, v] } }

      function(
        :from_list,
        { pairs: 'List(Tuple2(k, v))' },
        'Dict(k, v)',
        constraints: [['Basics.Eq', 'k']],
      ) do |pairs|
        pairs
          .each_with_object({}) { |pair, h| h[pair._1] = pair._2 }
          .then { Jade::Dict::Dict[it] }
      end

      function(
        :map,
        { dict: 'Dict(k, v)', fn: 'k, v -> v2' },
        'Dict(k, v2)',
      ) do |dict, fn|
        dict.hash
          .each_with_object({}) { |(k, v), h| h[k] = fn.call(k, v) }
          .then { Jade::Dict::Dict[it] }
      end

      function(
        :filter,
        { dict: 'Dict(k, v)', fn: 'k, v -> Bool' },
        'Dict(k, v)',
      ) do |dict, fn|
        dict.hash
          .select { |k, v| fn.call(k, v) }
          .then { Jade::Dict::Dict[it] }
      end

      function(
        :fold,
        { dict: 'Dict(k, v)', initial: 'b', fn: 'k, v, b -> b' },
        'b',
      ) do |dict, initial, fn|
        dict.hash.reduce(initial) { |acc, (k, v)| fn.call(k, v, acc) }
      end

      function(
        :union,
        { left: 'Dict(k, v)', right: 'Dict(k, v)' },
        'Dict(k, v)',
        constraints: [['Basics.Eq', 'k']],
      ) { |left, right| Jade::Dict::Dict[right.hash.merge(left.hash)] }

      function(
        :merge,
        { left: 'Dict(k, v)', right: 'Dict(k, v)', combine: 'v, v -> v' },
        'Dict(k, v)',
        constraints: [['Basics.Eq', 'k']],
      ) do |left, right, combine|
        right.hash
          .merge(left.hash) { |_k, r_val, l_val| combine.call(l_val, r_val) }
          .then { Jade::Dict::Dict[it] }
      end

      default_importing('Dict')

      function(
        'dict_eq',
        { a: 'Dict(k, v)', b: 'Dict(k, v)' },
        'Bool',
      ) { |a, b| a.hash == b.hash }
    end
  end
end
