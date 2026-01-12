require 'jade/stdlib/intrinsics'

module Jade
  module Stdlib
    module String
      extend Intrinsics

      import Basics
      # import Maybe

      union :String

      function :is_empty, { str: 'String'}, 'Bool' do |str|
        str.empty?
      end

      function :length, { str: 'String'}, 'Int' do |str|
        str.length
      end

      function :reverse, { str: 'String'}, 'String' do |str|
        str.reverse
      end

      function :reverse, { str: 'String'}, 'String' do |str|
        str.reverse
      end

      function :repeat, { str: 'String', times: 'Int' }, 'String' do |str, times|
        str * times
      end

      function :to_int, { str: 'String' }, 'Maybe(Int)' do |str|
        begin
          Integer(str)
            .then { ::Maybe::Just[it] }
        rescue
          ::Maybe::Nothing[]
        end
      end

      exposing :*
    end
  end
end
