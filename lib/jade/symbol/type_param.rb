module Jade
  module Symbol
    Param = Data.define(:name, :decl_span) do
      include Base
    end
  end
end
