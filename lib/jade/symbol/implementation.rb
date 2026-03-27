module Jade
  module Symbol
    Implementation = Data.define(
      :module_name,
      :interface,
      :type,
      :type_params,
      :constraints,
      :functions,
      :deps,
      :decl_span
    ) do
      include Base
    end
  end
end
