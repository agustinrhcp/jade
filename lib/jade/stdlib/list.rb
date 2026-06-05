require 'jade/stdlib/intrinsics'

module Jade
  module Stdlib
    module List
      extend Intrinsics

      import Maybe
      import Tuple

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
        :"empty?",
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
      ) { |list, fn| list.each_with_index.map { |x, i| fn.(i, x) } }

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
            [:stdlib_fn, 'List.sort_with'],
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
            [:stdlib_fn, 'List.sort_by_with'],
            [[:var, 'list'], [:var, 'key'], [:impl_arg, 0, 'compare']],
          ],
        ),
      )

      function(
        'sort_with',
        { list: 'List(a)', cmp: 'a, a -> Ordering' },
        'List(a)',
        private: true,
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
        'sort_by_with',
        { list: 'List(a)', key: 'a -> b', cmp: 'b, b -> Ordering' },
        'List(a)',
        private: true,
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

      function(
        :"any?",
        { list: 'List(a)', fn: 'a -> Bool' },
        'Bool',
      ) { |list, fn| list.any?(&fn) }

      function(
        :"all?",
        { list: 'List(a)', fn: 'a -> Bool' },
        'Bool',
      ) { |list, fn| list.all?(&fn) }

      function(
        :find,
        { list: 'List(a)', fn: 'a -> Bool' },
        'Maybe(a)',
      ) do |list, fn|
        match = list.find(&fn)
        match.nil? ? Jade::Maybe::Nothing[] : Jade::Maybe::Just[match]
      end

      function(
        :filter_map,
        { list: 'List(a)', fn: 'a -> Maybe(b)' },
        'List(b)',
      ) do |list, fn|
        list.flat_map do |x|
          case fn.call(x)
          in Jade::Maybe::Just[v] then [v]
          else []
          end
        end
      end

      function(
        :take,
        { list: 'List(a)', n: 'Int' },
        'List(a)',
      ) { |list, n| list.first([n, 0].max) }

      function(
        :drop,
        { list: 'List(a)', n: 'Int' },
        'List(a)',
      ) { |list, n| list.drop([n, 0].max) }

      function(
        :partition,
        { list: 'List(a)', fn: 'a -> Bool' },
        'Tuple2(List(a), List(a))',
      ) do |list, fn|
        pass, rest = list.partition(&fn)
        Jade::Tuple::Tuple2[pass, rest]
      end

      function(
        :concat,
        { lists: 'List(List(a))' },
        'List(a)',
      ) { it.flatten(1) }

      function(
        :zip,
        { left: 'List(a)', right: 'List(b)' },
        'List(Tuple2(a, b))',
      ) do |left, right|
        len = [left.length, right.length].min
        left.first(len).zip(right.first(len)).map { |(x, y)| Jade::Tuple::Tuple2[x, y] }
      end

      function(
        :unzip,
        { list: 'List(Tuple2(a, b))' },
        'Tuple2(List(a), List(b))',
      ) { |list| Jade::Tuple::Tuple2[list.map(&:_1), list.map(&:_2)] }

      function(
        :"member?",
        { list: 'List(a)', element: 'a' },
        'Bool',
        constraints: [['Basics.Eq', 'a']],
        body: Symbol::DerivedFunction.new(
          params: ['list', 'element'],
          body: [:call,
            [:stdlib_fn, 'List.member_with'],
            [[:var, 'list'], [:var, 'element'], [:impl_arg, 0, '(==)']],
          ],
        ),
      )

      function(
        'member_with',
        { list: 'List(a)', element: 'a', eq: 'a, a -> Bool' },
        'Bool',
        private: true,
      ) { |list, element, eq| list.any? { |x| eq.call(x, element) } }

      function(
        :maximum,
        { list: 'List(a)' },
        'Maybe(a)',
        constraints: [['Basics.Comparable', 'a']],
        body: Symbol::DerivedFunction.new(
          params: ['list'],
          body: [:call,
            [:stdlib_fn, 'List.maximum_with'],
            [[:var, 'list'], [:impl_arg, 0, 'compare']],
          ],
        ),
      )

      function(
        :minimum,
        { list: 'List(a)' },
        'Maybe(a)',
        constraints: [['Basics.Comparable', 'a']],
        body: Symbol::DerivedFunction.new(
          params: ['list'],
          body: [:call,
            [:stdlib_fn, 'List.minimum_with'],
            [[:var, 'list'], [:impl_arg, 0, 'compare']],
          ],
        ),
      )

      function(
        'maximum_with',
        { list: 'List(a)', cmp: 'a, a -> Ordering' },
        'Maybe(a)',
        private: true,
      ) do |list, cmp|
        if list.empty?
          Jade::Maybe::Nothing[]
        else
          best = list.reduce do |acc, x|
            cmp.call(x, acc).is_a?(Jade::Basics::GT) ? x : acc
          end
          Jade::Maybe::Just[best]
        end
      end

      function(
        'minimum_with',
        { list: 'List(a)', cmp: 'a, a -> Ordering' },
        'Maybe(a)',
        private: true,
      ) do |list, cmp|
        if list.empty?
          Jade::Maybe::Nothing[]
        else
          best = list.reduce do |acc, x|
            cmp.call(x, acc).is_a?(Jade::Basics::LT) ? x : acc
          end
          Jade::Maybe::Just[best]
        end
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
