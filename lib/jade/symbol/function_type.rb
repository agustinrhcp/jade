module Jade
  module Symbol
    FunctionType = Data.define(:params, :return_type) do
      include Base
    end
  end
end
