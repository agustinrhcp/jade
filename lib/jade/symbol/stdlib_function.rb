module Jade
  module Symbol
    StdlibFunction = Data.define(:module_name, :name, :params, :return_type, :codegen, :constraints) do
      include Base

      def to_ref
        ValueRef[module_name, name]
      end

      def constant?
        params.empty? && constraints.empty?
      end
    end
  end
end
