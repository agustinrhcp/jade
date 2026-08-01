require 'jade/debug'
require 'jade/stdlib/intrinsics'

module Jade
  module Stdlib
    module Debug
      extend Intrinsics

      function(:to_string, { value: 'a' }, 'String') { Jade::Debug.render(it) }
      function(:log, { label: 'String', value: 'a' }, 'a') { |l, v| Jade::Debug.log(l, v) }
    end
  end
end
