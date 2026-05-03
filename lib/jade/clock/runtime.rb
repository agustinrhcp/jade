require 'jade/port'

module Jade
  module Clock
    module Runtime
      extend Jade::Port

      task :now_raw do |t|
        t.ok({ millis: (::Time.now.to_r * 1000).to_i })
      end
    end
  end
end
