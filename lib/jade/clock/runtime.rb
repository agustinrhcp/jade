module Jade
  module Clock
    module Runtime
      extend self

      def now_raw
        Jade::Task.ok do
          { millis: (::Time.now.to_r * 1000).to_i }
        end
      end
    end
  end
end
