require 'jade/stdlib/intrinsics'

module Jade
  module Stdlib
    module Basics
      extend Intrinsics

      union :Never
      union :Int
      union :Float
      union :Bool

      native_type :Int,   Integer
      native_type :Float, ::Float
      native_type :Bool,  TrueClass, FalseClass

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

      interface(
        'Numeric',
        'a',
        { '(+)' => 'a, a -> a', '(-)' => 'a, a -> a', '(*)' => 'a, a -> a', '(/)' => 'a, a -> a' }
      )

      implementation('Numeric', 'Int',   '(+)' => 'int_add', '(-)' => 'int_sub', '(*)' => 'int_mul', '(/)' => 'int_div')
      implementation('Numeric', 'Float', '(+)' => 'float_add', '(-)' => 'float_sub', '(*)' => 'float_mul', '(/)' => 'float_div')

      interface(
        'Appendable',
        'a',
        { '(++)' => 'a, a -> a' },
      )

      interface(
        'Mappable',
        'f',
        { 'map' => 'f(a), (a -> b) -> f(b)' },
      )

      interface(
        'Chainable',
        'f',
        { 'and_then' => 'f(a), (a -> f(b)) -> f(b)' },
      )

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

      function('int_add', { a: 'Int', b: 'Int' }, 'Int')
      function('int_sub', { a: 'Int', b: 'Int' }, 'Int')
      function('int_mul', { a: 'Int', b: 'Int' }, 'Int')
      function('int_div', { a: 'Int', b: 'Int' }, 'Int')
      function('mod', { a: 'Int', b: 'Int' }, 'Int')

      function('float_add', { a: 'Float', b: 'Float' }, 'Float')
      function('float_sub', { a: 'Float', b: 'Float' }, 'Float')
      function('float_mul', { a: 'Float', b: 'Float' }, 'Float')
      function('float_div', { a: 'Float', b: 'Float' }, 'Float')

      function(:to_float, { n: 'Int' }, 'Float')
      function(:floor, { n: 'Float' }, 'Int')
      function(:ceiling, { n: 'Float' }, 'Int')
      function(:round, { n: 'Float' }, 'Int')
      function(:truncate, { n: 'Float' }, 'Int')

      function('identity', { a: 'a' }, 'a')
      function('always', { x: 'a' }, 'b -> a')
      function('not', { a: 'Bool' }, 'Bool')

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
        'min',
        { a: 'a', b: 'a' },
        'a',
        constraints: [['Basics.Comparable', 'a']],
        body: Symbol::DerivedFunction.new(
          params: ['a', 'b'],
          body: [:case,
            [:call, [:impl_arg, 0, 'compare'], [[:var, 'a'], [:var, 'b']]],
            [
              [[:constructor, 'Basics.GT', []], [[:var, 'b']]],
              [[:_], [[:var, 'a']]],
            ],
          ],
        ),
      )

      function(
        'max',
        { a: 'a', b: 'a' },
        'a',
        constraints: [['Basics.Comparable', 'a']],
        body: Symbol::DerivedFunction.new(
          params: ['a', 'b'],
          body: [:case,
            [:call, [:impl_arg, 0, 'compare'], [[:var, 'a'], [:var, 'b']]],
            [
              [[:constructor, 'Basics.LT', []], [[:var, 'b']]],
              [[:_], [[:var, 'a']]],
            ],
          ],
        ),
      )

      function('(&&)', { a: 'Bool', b: 'Bool' }, 'Bool')
      function('(||)', { a: 'Bool', b: 'Bool' }, 'Bool')

      default_importing :*

      function('int_eq', { one: 'Int', other: 'Int' }, 'Bool')
      function('float_eq', { one: 'Float', other: 'Float' }, 'Bool')
      function('bool_eq', { one: 'Bool', other: 'Bool' }, 'Bool')
      function('int_compare', { a: 'Int', b: 'Int' }, 'Ordering')
      function('float_compare', { a: 'Float', b: 'Float' }, 'Ordering')
    end
  end
end
