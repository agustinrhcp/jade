require 'jade/debug'
require 'jade/stdlib/intrinsics'

module Jade
  module Stdlib
    module Debug
      extend Intrinsics

      function(:to_string, { value: 'a' }, 'String') { Jade::Debug.render(it) }
    end
  end
end
