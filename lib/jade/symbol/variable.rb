module Jade
  module Symbol
    Variable = Data.define(:name, :decl_span) do
      include Base
    end
  end
end
