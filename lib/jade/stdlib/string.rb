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

      function('str_compare', { a: 'String', b: 'String' }, 'Ordering')
      function('str_append', { a: 'String', b: 'String' }, 'String')
      function(:"empty?", { str: 'String' }, 'Bool')
      function(:length, { str: 'String' }, 'Int')
      function(:reverse, { str: 'String' }, 'String')
      function(:uncons, { str: 'String' }, 'Maybe(Tuple2(Char, String))')
      function(:cons, { head: 'Char', tail: 'String' }, 'String')
      function(:from_char, { char: 'Char' }, 'String')
      function(:map, { str: 'String', fn: 'Char -> Char' }, 'String')
      function(:repeat, { str: 'String', times: 'Int' }, 'String')
      function(:to_int, { str: 'String' }, 'Maybe(Int)')
      function(:from_int, { n: 'Int' }, 'String')
      function(:split, { str: 'String', by: 'String' }, 'List(String)')
      function(:concat, { list: 'List(String)' }, 'String')
      function(:join, { list: 'List(String)', with: 'String' }, 'String')
      function(:trim, { str: 'String' }, 'String')
      function(:trim_left, { str: 'String' }, 'String')
      function(:trim_right, { str: 'String' }, 'String')
      function(:to_lower, { str: 'String' }, 'String')
      function(:to_upper, { str: 'String' }, 'String')
      function(:"contains?", { str: 'String', sub: 'String' }, 'Bool')
      function(:"starts_with?", { str: 'String', prefix: 'String' }, 'Bool')
      function(:"ends_with?", { str: 'String', suffix: 'String' }, 'Bool')
      function(:replace, { str: 'String', target: 'String', replacement: 'String' }, 'String')

      # Half-open slice. Negative offsets count from the end (Ruby `s[i...j]`
      # semantics). Out-of-range returns an empty string rather than nil.
      function(:slice, { str: 'String', start: 'Int', end_: 'Int' }, 'String')

      function(:words, { str: 'String' }, 'List(String)')
      function(:lines, { str: 'String' }, 'List(String)')
      function(:to_list, { str: 'String' }, 'List(Char)')
      function(:from_list, { chars: 'List(Char)' }, 'String')

      default_importing('String')

      function('str_eq', { one: 'String', other: 'String' }, 'Bool')
    end
  end
end
