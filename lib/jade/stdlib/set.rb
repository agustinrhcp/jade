require 'jade/stdlib/intrinsics'

module Jade
  module Stdlib
    module Set
      extend Intrinsics

      import Basics
      import Maybe
      import List

      union :Set, 'a'

      native_type :Set, Jade::Set::Set

      implementation('Eq', 'Set', '(==)' => 'set_eq')

      function(:empty, {}, 'Set(a)')

      function(
        :singleton,
        { value: 'a' },
        'Set(a)',
        constraints: [['Basics.Eq', 'a']],
      )

      function(:"empty?", { set: 'Set(a)' }, 'Bool')
      function(:size, { set: 'Set(a)' }, 'Int')

      function(
        :"member?",
        { set: 'Set(a)', value: 'a' },
        'Bool',
        constraints: [['Basics.Eq', 'a']],
      )

      function(
        :insert,
        { set: 'Set(a)', value: 'a' },
        'Set(a)',
        constraints: [['Basics.Eq', 'a']],
      )

      function(
        :remove,
        { set: 'Set(a)', value: 'a' },
        'Set(a)',
        constraints: [['Basics.Eq', 'a']],
      )

      function(:to_list, { set: 'Set(a)' }, 'List(a)')

      function(
        :from_list,
        { values: 'List(a)' },
        'Set(a)',
        constraints: [['Basics.Eq', 'a']],
      )

      function(
        :map,
        { set: 'Set(a)', fn: 'a -> b' },
        'Set(b)',
        constraints: [['Basics.Eq', 'b']],
      ) do |set, fn|
        set.hash.keys
          .each_with_object({}) { |v, h| h[fn.call(v)] = true }
          .then { Jade::Set::Set[it] }
      end

      function(
        :filter,
        { set: 'Set(a)', fn: 'a -> Bool' },
        'Set(a)',
      ) do |set, fn|
        set.hash
          .select { |k, _| fn.call(k) }
          .then { Jade::Set::Set[it] }
      end

      function(
        :fold,
        { set: 'Set(a)', initial: 'b', fn: 'a, b -> b' },
        'b',
      ) do |set, initial, fn|
        set.hash.keys.reduce(initial) { |acc, v| fn.call(v, acc) }
      end

      function(
        :union,
        { left: 'Set(a)', right: 'Set(a)' },
        'Set(a)',
        constraints: [['Basics.Eq', 'a']],
      )

      function(
        :intersect,
        { left: 'Set(a)', right: 'Set(a)' },
        'Set(a)',
        constraints: [['Basics.Eq', 'a']],
      ) do |left, right|
        left.hash
          .select { |k, _| right.hash.key?(k) }
          .then { Jade::Set::Set[it] }
      end

      function(
        :diff,
        { left: 'Set(a)', right: 'Set(a)' },
        'Set(a)',
        constraints: [['Basics.Eq', 'a']],
      ) do |left, right|
        left.hash
          .reject { |k, _| right.hash.key?(k) }
          .then { Jade::Set::Set[it] }
      end

      default_importing('Set')

      function('set_eq', { a: 'Set(a)', b: 'Set(a)' }, 'Bool')
    end
  end
end
