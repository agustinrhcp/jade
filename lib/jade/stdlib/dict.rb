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

      function(:empty, {}, 'Dict(k, v)')

      function(
        :singleton,
        { key: 'k', value: 'v' },
        'Dict(k, v)',
        constraints: [['Basics.Eq', 'k']],
      )

      function(:"empty?", { dict: 'Dict(k, v)' }, 'Bool')
      function(:size, { dict: 'Dict(k, v)' }, 'Int')

      function(
        :get,
        { dict: 'Dict(k, v)', key: 'k' },
        'Maybe(v)',
        constraints: [['Basics.Eq', 'k']],
      )

      function(
        :"member?",
        { dict: 'Dict(k, v)', key: 'k' },
        'Bool',
        constraints: [['Basics.Eq', 'k']],
      )

      function(
        :insert,
        { dict: 'Dict(k, v)', key: 'k', value: 'v' },
        'Dict(k, v)',
        constraints: [['Basics.Eq', 'k']],
      )

      function(
        :remove,
        { dict: 'Dict(k, v)', key: 'k' },
        'Dict(k, v)',
        constraints: [['Basics.Eq', 'k']],
      )

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

      function(:keys, { dict: 'Dict(k, v)' }, 'List(k)')
      function(:values, { dict: 'Dict(k, v)' }, 'List(v)')
      function(:to_list, { dict: 'Dict(k, v)' }, 'List(Tuple2(k, v))')

      function(
        :from_list,
        { pairs: 'List(Tuple2(k, v))' },
        'Dict(k, v)',
        constraints: [['Basics.Eq', 'k']],
      )

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
      )

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

      function('dict_eq', { a: 'Dict(k, v)', b: 'Dict(k, v)' }, 'Bool')
    end
  end
end
