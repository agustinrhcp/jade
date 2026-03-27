module Jade
  module Symbol
    ImplementationTemplate = Data.define(
      :interface,
      :type,
      :type_params,
      :constraints,
      :functions,
    ) do
      include Base
    end
  end
end
