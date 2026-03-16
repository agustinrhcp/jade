require 'jade/stdlib/intrinsics'

module Jade
  module Stdlib
    module Basics
      extend Intrinsics

      union :Int
      union :Float
      union :Bool

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
        '(==)',
        { a: 'Int', b: 'Int' },
        'Bool',
      ) { |a, b| a == b }

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
    end
  end
end
