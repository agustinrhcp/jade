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
          .then { Jade::Maybe::Just[it] }
      rescue RangeError
        Jade::Maybe::Nothing[]
      end

      function(
        :"digit?",
        { char: 'Char' },
        'Bool',
      ) { it.match?(/\d/) }

      function(
        :"alpha?",
        { char: 'Char' },
        'Bool',
      ) { it.match?(/[a-zA-Z]/) }

      function(
        :"alpha_numeric?",
        { char: 'Char' },
        'Bool',
      ) { it.match?(/[a-zA-Z0-9]/) }

      function(
        :"upper?",
        { char: 'Char' },
        'Bool',
      ) { it.match?(/[A-Z]/) }

      function(
        :"lower?",
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
