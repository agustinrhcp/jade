require 'jade/stdlib/intrinsics'

module Jade
  module Stdlib
    module Char
      extend Intrinsics

      import Basics

      union :Char

      implementation('Eq', 'Char', '(==)' => 'char_eq')

      function(:to_code, { char: 'Char' }, 'Int')
      function(:from_code, { code: 'Int' }, 'Maybe(Char)')
      function(:"digit?", { char: 'Char' }, 'Bool')
      function(:"alpha?", { char: 'Char' }, 'Bool')
      function(:"alpha_numeric?", { char: 'Char' }, 'Bool')
      function(:"upper?", { char: 'Char' }, 'Bool')
      function(:"lower?", { char: 'Char' }, 'Bool')

      default_importing('Char')

      function('char_eq', { one: 'Char', other: 'Char' }, 'Bool')
    end
  end
end
