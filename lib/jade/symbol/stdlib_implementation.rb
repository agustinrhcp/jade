module Jade
  module Symbol
    StdlibImplementation = Data.define(:params, :body) do
      include Base
    end
  end
end
