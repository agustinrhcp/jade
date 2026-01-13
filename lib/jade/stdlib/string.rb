require 'jade/stdlib/intrinsics'

module Jade
  module Stdlib
    module String
      extend Intrinsics

      import Basics
      import Maybe
      import List

      union :String

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

      default_importing('String')
    end
  end
end
