require 'jade/frontend/pattern_analysis/matrix'
require 'jade/frontend/pattern_analysis/exhaustiveness'

module Jade
  module Frontend
    module PatternAnalysis
      Wildcard = Data.define do
        def wildcard?; true; end
        def to_s; '_'; end
      end

      Literal = Data.define(:value, :type) do
        def wildcard?; false; end
        def to_s; value.inspect; end
      end

      Constructor = Data.define(:constructor, :args) do
        def wildcard?; false; end

        def to_s
          if constructor.start_with?('Tuple.')
            "(#{args.map(&:to_s).join(', ')})"
          else
            name = constructor.split('.').last
            args.empty? ? name : "#{name}(#{args.map(&:to_s).join(', ')})"
          end
        end
      end

      Record = Data.define(:fields) do
        def wildcard?; false; end

        def to_s
          fields_str = fields.map { |k, v| "#{k}: #{v}" }.join(', ')
          "{ #{fields_str} }"
        end
      end
    end
  end
end
