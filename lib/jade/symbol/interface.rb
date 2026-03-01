module Jade
  module Symbol
    Interface = Data.define(:module_name, :name, :type_param, :functions, :decl_span) do
      include Base
    end
  end
end
