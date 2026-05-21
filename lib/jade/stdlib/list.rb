require 'jade/stdlib/intrinsics'

module Jade
  module Stdlib
    module List
      extend Intrinsics

      import Maybe

      union :List, 'a'

      function(
        :singleton,
        { element: 'a' },
        'List(a)'
      ) { |element| [element] }

      function(
        :repeat,
        { element: 'a', times: 'Int' },
        'List(a)'
      ) { |element, times| [element] * times }

      function(
        :range,
        { begin_: 'Int', end_: 'Int' },
        'List(a)',
      ) { |begin_, end_| (begin_..end_).to_a }

      function(
        :is_empty,
        { list: 'List(a)' },
        'Bool',
      ) { |list| list.empty? }

      function(
        :head,
        { list: 'List(a)' },
        'Maybe(a)',
      ) { |list| list.empty? ? Jade::Maybe::Nothing[] : Jade::Maybe::Just[list.first] }

      function(
        :tail,
        { list: 'List(a)' },
        'List(a)',
      ) { |list| list.drop(1) }

      function(
        :length,
        { list: 'List(a)' },
        'Int',
      ) { |list| list.length }

      function(
        :reverse,
        { list: 'List(a)' },
        'List(a)',
      ) { |list| list.reverse }

      # Transform

      function(
        :map,
        { list: 'List(a)', fn: 'a -> b' },
        'List(b)',
      ) { |list, fn| list.map(&fn) }

      function(
        :and_then,
        { list: 'List(a)', fn: 'a -> List(b)' },
        'List(b)',
      ) { |list, fn| list.flat_map(&fn) }

      function(
        :indexed_map,
        { list: 'List(a)', fn: 'Int, a -> b' },
        'List(b)',
      ) { |list, fn| list.map.with_index(&fn) }

      function(
        :fold,
        { list: 'List(a)', initial: 'b', fn: 'b, a -> b' },
        'b',
      ) { |list, initial, fn| list.reduce(initial, &fn) }

      function(
        :filter,
        { list: 'List(a)', fn: 'a -> Bool' },
        'List(a)',
      ) { |list, fn| list.filter(&fn) }

      function(
        :sort,
        { list: 'List(a)' },
        'List(a)',
        constraints: [['Basics.Comparable', 'a']],
        body: Symbol::DerivedFunction.new(
          params: ['list'],
          body: [:call,
            [:stdlib_fn, 'List._sort_with'],
            [[:var, 'list'], [:impl_arg, 0, 'compare']],
          ],
        ),
      )

      function(
        :sort_by,
        { list: 'List(a)', key: 'a -> b' },
        'List(a)',
        constraints: [['Basics.Comparable', 'b']],
        body: Symbol::DerivedFunction.new(
          params: ['list', 'key'],
          body: [:call,
            [:stdlib_fn, 'List._sort_by_with'],
            [[:var, 'list'], [:var, 'key'], [:impl_arg, 0, 'compare']],
          ],
        ),
      )

      function(
        '_sort_with',
        { list: 'List(a)', cmp: 'a, a -> Ordering' },
        'List(a)',
      ) do |list, cmp|
        list.sort do |x, y|
          case cmp.call(x, y)
          in Jade::Basics::LT then -1
          in Jade::Basics::GT then 1
          else 0
          end
        end
      end

      function(
        '_sort_by_with',
        { list: 'List(a)', key: 'a -> b', cmp: 'b, b -> Ordering' },
        'List(a)',
      ) do |list, key, cmp|
        list
          .map { |x| [x, key.call(x)] }
          .sort do |(_, ka), (_, kb)|
            case cmp.call(ka, kb)
            in Jade::Basics::LT then -1
            in Jade::Basics::GT then 1
            else 0
            end
          end
          .map(&:first)
      end

      implementation('Appendable', 'List', '(++)' => 'list_append')
      implementation('Mappable', 'List', 'map' => 'map')
      implementation('Chainable', 'List', 'and_then' => 'and_then')

      function(
        'list_append',
        { a: 'List(a)', b: 'List(a)' },
        'List(a)',
      ) { |a, b| a + b }

      default_importing('List')
    end
  end
end
