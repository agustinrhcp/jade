module Jade
  module Parsing
    module Token
      def identifier
        type(:identifier)
      end

      def constant
        type(:constant)
      end
    end
  end
end
