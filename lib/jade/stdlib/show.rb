require 'jade/stdlib/intrinsics'

module Jade
  module Stdlib
    module Show
      extend Intrinsics

      import Basics
      import Char
      import String

      interface(
        'Show',
        'a',
        { 'show' => 'a -> String' },
      )

      implementation('Show', 'Int',    'show' => 'int_show')
      implementation('Show', 'Float',  'show' => 'float_show')
      implementation('Show', 'Bool',   'show' => 'bool_show')
      implementation('Show', 'String', 'show' => 'str_show')
      implementation('Show', 'Char',   'show' => 'char_show')

      # Never is uninhabited, so this can only be reached by a compiler bug.
      # The instance exists because the constraint does: without it no
      # `Result(a, Never)` — the shape every port-free task returns — can be
      # shown, and the error surfaces as an unresolved constraint far from
      # its cause.
      implementation('Show', 'Never',  'show' => 'never_show')

      function('int_show',   { n: 'Int' },    'String')
      function('float_show', { f: 'Float' },  'String')
      function('bool_show',  { b: 'Bool' },   'String')
      function('str_show',   { s: 'String' }, 'String')
      function('char_show',  { c: 'Char' },   'String')

      function('never_show', { n: 'Never' },  'String')
    end
  end
end
