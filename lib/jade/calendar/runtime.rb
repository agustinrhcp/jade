require 'jade/tasks'

module Jade
  module Calendar
    module Runtime
      extend Jade::Tasks::Module

      task :today_raw do |t|
        ::Time.now
          .then { { year: it.year, month: it.month, day: it.day } }
          .then { t.ok(it) }
      end
    end
  end
end
