require 'jade/debug'
require 'jade/stdlib/intrinsics'

module Jade
  module Stdlib
    module Debug
      extend Intrinsics

      function(:log, { label: 'String', value: 'a' }, 'a') { |l, v| Jade::Debug.log(l, v) }
    end
  end
end
