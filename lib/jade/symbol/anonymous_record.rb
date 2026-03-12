module Jade
  module Symbol
    AnonymousRecord = Data.define(:fields, :row_var) do
      include Base
    end
  end
end
