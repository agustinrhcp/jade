module Jade
  module Symbol
    module Base
      def qualified_name
        [module_name, name].join('.')
      end
    end
  end
end
