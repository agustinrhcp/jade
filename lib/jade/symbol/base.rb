module Jade
  module Symbol
    module Base
      def qualified_name
        [module_name, name].join('.')
      end

      alias_method :qname, :qualified_name

      def constructor_refs
        []
      end
    end
  end
end
