require 'jade/stdlib/intrinsics'

module Jade
  module Stdlib
    module String
      extend Intrinsics

      import Basics
      import Maybe
      import List
      import Char
      import Tuple

      union :String

      native_type :String, ::String

      implementation('Eq', 'String', '(==)' => 'str_eq')
      implementation('Appendable', 'String', '(++)' => 'str_append')
      implementation('Comparable', 'String', 'compare' => 'str_compare')

      function(
        'str_compare',
        { a: 'String', b: 'String' },
        'Ordering',
      ) { |a, b| a < b ? ::Basics::LT[] : a > b ? ::Basics::GT[] : ::Basics::EQ[] }

      function(
        'str_append',
        { a: 'String', b: 'String' },
        'String',
      ) { |a, b| a + b }

      function(
        :is_empty,
        { str: 'String'},
        'Bool',
      ) { it.empty? }

      function(
        :length,
        { str: 'String' },
        'Int'
      ) { it.length }

      function(
        :reverse,
        { str: 'String'},
        'String',
      ) { it.reverse }

      function(
        :uncons,
        { str: 'String' },
        'Maybe(Tuple2(Char, String))',
      ) do |str|
        str.empty? ? ::Maybe::Nothing[] : ::Maybe::Just[::Tuple::Tuple2[str[0], str[1..]]]
      end

      function(
        :cons,
        { head: 'Char', tail: 'String' },
        'String',
      ) { |head, tail| head + tail }

      function(
        :from_char,
        { char: 'Char' },
        'String',
      ) { |char| char }

      function(
        :map,
        { str: 'String', fn: 'Char -> Char' },
        'String',
      ) { |str, fn| str.chars.map(&fn).join }

      function(
        :repeat,
        { str: 'String', times: 'Int' },
        'String'
      ) { |str, times| str * times }

      function(
        :to_int,
        { str: 'String' },
        'Maybe(Int)'
      ) do |str|
        begin
          Integer(str)
            .then { ::Maybe::Just[it] }
        rescue
          ::Maybe::Nothing[]
        end
      end

      function(
        :split,
        { str: 'String', by: 'String' },
        'List(String)',
      ) { |str, by| str.split(by) }

      function(
        :concat,
        { list: 'List(String)' },
        'String'
      ) { it.join }

      function(
        :join,
        { list: 'List(String)', with: 'String' },
        'String'
      ) { |list, with| list.join(with) }

      default_importing('String')

      function(
        'str_eq',
        { one: 'String', other: 'String' },
        'Bool',
      ) { |one, other| one == other }

    end
  end
end
