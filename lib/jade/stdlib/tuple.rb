require 'jade/stdlib/intrinsics'

module Jade
  module Stdlib
    module Tuple
      extend Intrinsics

      union :Tuple2, 'a', 'b', constructor: true
      union :Tuple3, 'a', 'b', 'c', constructor: true
      union :Tuple4, 'a', 'b', 'c', 'd', constructor: true

      function(
        :pair,
        { first: 'a', second: 'b' },
        'Tuple2(a, b)',
      ) { |first, second| Jade::Tuple::Tuple2[first, second] }

      function(
        :first,
        { pair: 'Tuple2(a, b)' },
        'a',
      ) { |pair| pair._1 }

      function(
        :second,
        { pair: 'Tuple2(a, b)' },
        'b',
      ) { |pair| pair._2 }

      def self.constructor_by_arity(arity)
        "Tuple.Tuple#{arity}"
      end
    end
  end
end
