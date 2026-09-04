module Jade
  module Type
    Function = Data.define(:args, :return_type) do
      include Base

      # `Int, Int -> Int`, the spelling the formatter writes. Parentheses
      # around a comma list are a tuple, so a nested function keeps its own.
      def to_s
        params = args.empty? ? '()' : args.map { delimited(it) }.join(', ')

        "#{params} -> #{delimited(return_type)}"
      end

      def unbound_vars
        (args.flat_map(&:unbound_vars) + return_type.unbound_vars)
          .to_set.to_a
      end

      private

      def delimited(type)
        type.is_a?(Function) ? "(#{type})" : type.to_s
      end
    end
  end
end
