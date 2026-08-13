module Jade
  module Symbol
    # `effect` names the capability an intrinsic performs, or nil when it is
    # pure. Ports are the usual effect boundary, but an intrinsic runs Ruby
    # directly and so escapes it — `Debug.log` writes to the outside world
    # while looking exactly like `List.map`. Only the compiler authors can
    # tell them apart, so the marker is explicit and the default is pure.
    StdlibFunction = Data.define(
      :module_name, :name, :params, :return_type, :codegen, :constraints, :effect
    ) do
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
