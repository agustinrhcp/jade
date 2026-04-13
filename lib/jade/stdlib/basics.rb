require 'jade/stdlib/intrinsics'

module Jade
  module Stdlib
    module Basics
      extend Intrinsics

      union :Int
      union :Float
      union :Bool

      interface(
        'Eq',
        'a',
        { '(==)' => 'a, a -> Bool' },
      )

      implementation('Eq', 'Int',   '(==)' => 'int_eq')
      implementation('Eq', 'Float', '(==)' => 'float_eq')
      implementation('Eq', 'Bool',  '(==)' => 'bool_eq')

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
        '(<=)',
        { a: 'Int', b: 'Int' },
        'Bool',
      ) { |a, b| a <= b }

      function(
        '(>=)',
        { a: 'Int', b: 'Int' },
        'Bool',
      ) { |a, b| a >= b }

      function(
        '(>)',
        { a: 'Int', b: 'Int' },
        'Bool',
      ) { |a, b| a > b }

      function(
        '(<)',
        { a: 'Int', b: 'Int' },
        'Bool',
      ) { |a, b| a < b }

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
    end
  end
end
