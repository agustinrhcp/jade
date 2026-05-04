module Jade
  module Calendar
    module Runtime
      extend self

      def today_raw
        Jade::Task.ok do
          ::Time.now
            .then { { year: it.year, month: it.month, day: it.day } }
        end
      end
    end
  end
end
