require 'jade/stdlib/intrinsics'

module Jade
  module Stdlib
    module Basics
      extend Intrinsics

      union :Int
      union :Float
      union :Bool

      function('(+)', { a: 'Int', b: 'Int' }, 'Int') do |a, b|
        a + b
      end

      function('(-)', { a: 'Int', b: 'Int' }, 'Int') do |a, b|
        a - b
      end

      function('(*)', { a: 'Int', b: 'Int' }, 'Int') do |a, b|
        a * b
      end

      function('(/)', { a: 'Int', b: 'Int' }, 'Int') do |a, b|
        a / b
      end

      exposing :*
    end
  end
end
