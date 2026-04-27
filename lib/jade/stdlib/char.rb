require 'jade/stdlib/intrinsics'

module Jade
  module Stdlib
    module Char
      extend Intrinsics

      import Basics

      union :Char

      implementation('Eq', 'Char', '(==)' => 'char_eq')

      function(
        :to_code,
        { char: 'Char' },
        'Int',
      ) { it.ord }

      function(
        :from_code,
        { code: 'Int' },
        'Maybe(Char)',
      ) do |code|
        code.chr
          .then { ::Maybe::Just[it] }
      rescue RangeError
        ::Maybe::Nothing[]
      end

      function(
        :is_digit,
        { char: 'Char' },
        'Bool',
      ) { it.match?(/\d/) }

      function(
        :is_alpha,
        { char: 'Char' },
        'Bool',
      ) { it.match?(/[a-zA-Z]/) }

      function(
        :is_alpha_num,
        { char: 'Char' },
        'Bool',
      ) { it.match?(/[a-zA-Z0-9]/) }

      function(
        :is_upper,
        { char: 'Char' },
        'Bool',
      ) { it.match?(/[A-Z]/) }

      function(
        :is_lower,
        { char: 'Char' },
        'Bool',
      ) { it.match?(/[a-z]/) }

      default_importing('Char')

      function(
        'char_eq',
        { one: 'Char', other: 'Char' },
        'Bool',
      ) { |one, other| one == other }
    end
  end
end
