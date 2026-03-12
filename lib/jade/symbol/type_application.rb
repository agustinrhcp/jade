module Jade
  module Symbol
    TypeApplication = Data.define(:constructor, :args, :span) do
      include Base
    end

  end
end
