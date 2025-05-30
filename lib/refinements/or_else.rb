module Refinements
  module OrElse
    refine NilClass do
      def or_else
        yield
      end
    end

    refine Object do
      def or_else
        self
      end
    end
  end
end
