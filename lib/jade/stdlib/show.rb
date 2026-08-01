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

      function('int_show',   { n: 'Int' },    'String')
      function('float_show', { f: 'Float' },  'String')
      function('bool_show',  { b: 'Bool' },   'String')
      function('str_show',   { s: 'String' }, 'String')
      function('char_show',  { c: 'Char' },   'String')
    end
  end
end
