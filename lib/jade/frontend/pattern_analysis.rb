require 'jade/frontend/pattern_analysis/matrix'
require 'jade/frontend/pattern_analysis/exhaustiveness'

module Jade
  module Frontend
    module PatternAnalysis
      Wildcard = Data.define do
        def wildcard?; true; end
      end

      Literal = Data.define(:value, :type) do
        def wildcard?; false; end
      end

      Constructor = Data.define(:constructor, :args) do
        def wildcard?; false; end
      end

      Record = Data.define(:fields) do
        def wildcard?; false; end
      end
    end
  end
end
