require 'jade/stdlib/intrinsics'

module Jade
  module Stdlib
    # A named effect: a port and its arguments, described entirely by data.
    #
    # Ports return a Call rather than a Task because a Call can be written
    # down — serialized, logged, enqueued, reconstructed in another process.
    # Composing one with map/and_then embeds a closure, which cannot, so the
    # combinators widen a Call to a Task and there is no way back.
    #
    # Deliberately not Mappable or Chainable: those require map to return
    # f(b), and mapping a Call yields a Task.
    module Call
      extend Intrinsics

      union :Call, :a, :e

      def self.default_imports
        [Symbol.type_ref('Call', 'Call')]
      end
    end
  end
end
