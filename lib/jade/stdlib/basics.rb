require 'jade/stdlib/intrinsics'

module Jade
  module Stdlib
    module Basics
      extend Intrinsics

      union :Int
      union :Float
      union :Bool

      # interface('Eq', 'a', { '(==)' => 'a, a -> Bool' })

      # implementation(:Eq, 'Int', 'int_eq')

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

      default_importing :*

      function(
        'int_eq',
        { one: 'Int', other: 'Int' },
        'Bool',
      ) { |one, other| one == other }
    end
  end
end
