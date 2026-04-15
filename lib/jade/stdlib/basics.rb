require 'jade/stdlib/intrinsics'

module Jade
  module Stdlib
    module Basics
      extend Intrinsics

      union :Int
      union :Float
      union :Bool

      union :Ordering
      variant :GT, of: :Ordering
      variant :EQ, of: :Ordering
      variant :LT, of: :Ordering

      interface(
        'Eq',
        'a',
        { '(==)' => 'a, a -> Bool' },
      )

      implementation('Eq', 'Int',   '(==)' => 'int_eq')
      implementation('Eq', 'Float', '(==)' => 'float_eq')
      implementation('Eq', 'Bool',  '(==)' => 'bool_eq')

      interface(
        'Comparable',
        'a',
        { 'compare' => 'a, a -> Ordering' },
      )

      implementation('Comparable', 'Int',   'compare' => 'int_compare')
      implementation('Comparable', 'Float', 'compare' => 'float_compare')

      function(
        '(!=)',
        { one: 'a', other: 'a' },
        'Bool',
        constraints: [['Basics.Eq', 'a']],
        body: Symbol::DerivedFunction.new(
          params: ['one', 'other'],
          body: [:!, [:call, [:impl_arg, 0, '(==)'], [[:var, 'one'], [:var, 'other']]]],
        ),
      )

      function(
        '(+)',
        { a: 'Int', b: 'Int' },
        'Int',
      ) { |a, b| a + b }

      function(
        '(-)',
        { a: 'Int', b: 'Int' },
        'Int',
      ) { |a, b| a - b }

      function(
        '(*)',
        { a: 'Int', b: 'Int' },
        'Int',
      ) { |a, b| a * b }

      function(
        '(/)',
        { a: 'Int', b: 'Int' },
        'Int',
      ) { |a, b| a / b }

      function(
        'identity',
        { a: 'a' },
        'a',
      ) { it }

      function(
        'not',
        { a: 'Bool' },
        'Bool',
      ) { not it }

      function(
        '(<)',
        { a: 'a', b: 'a' },
        'Bool',
        constraints: [['Basics.Comparable', 'a']],
        body: Symbol::DerivedFunction.new(
          params: ['a', 'b'],
          body: [:case,
            [:call, [:impl_arg, 0, 'compare'], [[:var, 'a'], [:var, 'b']]],
            [
              [[:constructor, 'Basics.LT', []], [true]],
              [[:_], [false]],
            ],
          ],
        ),
      )

      function(
        '(>)',
        { a: 'a', b: 'a' },
        'Bool',
        constraints: [['Basics.Comparable', 'a']],
        body: Symbol::DerivedFunction.new(
          params: ['a', 'b'],
          body: [:case,
            [:call, [:impl_arg, 0, 'compare'], [[:var, 'a'], [:var, 'b']]],
            [
              [[:constructor, 'Basics.GT', []], [true]],
              [[:_], [false]],
            ],
          ],
        ),
      )

      function(
        '(<=)',
        { a: 'a', b: 'a' },
        'Bool',
        constraints: [['Basics.Comparable', 'a']],
        body: Symbol::DerivedFunction.new(
          params: ['a', 'b'],
          body: [:case,
            [:call, [:impl_arg, 0, 'compare'], [[:var, 'a'], [:var, 'b']]],
            [
              [[:constructor, 'Basics.GT', []], [false]],
              [[:_], [true]],
            ],
          ],
        ),
      )

      function(
        '(>=)',
        { a: 'a', b: 'a' },
        'Bool',
        constraints: [['Basics.Comparable', 'a']],
        body: Symbol::DerivedFunction.new(
          params: ['a', 'b'],
          body: [:case,
            [:call, [:impl_arg, 0, 'compare'], [[:var, 'a'], [:var, 'b']]],
            [
              [[:constructor, 'Basics.LT', []], [false]],
              [[:_], [true]],
            ],
          ],
        ),
      )

      function(
        '(&&)',
        { a: 'Bool', b: 'Bool' },
        'Bool',
      ) { |a, b| a && b }

      function(
        '(||)',
        { a: 'Bool', b: 'Bool' },
        'Bool',
      ) { |a, b| a || b }

      default_importing :*

      function(
        'int_eq',
        { one: 'Int', other: 'Int' },
        'Bool',
      ) { |one, other| one == other }

      function(
        'float_eq',
        { one: 'Float', other: 'Float' },
        'Bool',
      ) { |one, other| one == other }

      function(
        'bool_eq',
        { one: 'Bool', other: 'Bool' },
        'Bool',
      ) { |one, other| one == other }

      function(
        'int_compare',
        { a: 'Int', b: 'Int' },
        'Ordering',
      ) { |a, b| a < b ? ::Basics::LT[] : a > b ? ::Basics::GT[] : ::Basics::EQ[] }

      function(
        'float_compare',
        { a: 'Float', b: 'Float' },
        'Ordering',
      ) { |a, b| a < b ? ::Basics::LT[] : a > b ? ::Basics::GT[] : ::Basics::EQ[] }
    end
  end
end
