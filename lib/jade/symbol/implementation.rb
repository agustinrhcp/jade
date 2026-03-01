module Jade
  module Symbol
    Implementation = Data.define(:module_name, :name, :interface, :type, :functions, :decl_span) do
      include Base
    end
  end
end
