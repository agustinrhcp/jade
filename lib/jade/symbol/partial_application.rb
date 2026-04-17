module Jade
  module Symbol
    PartialApplication = Data.define(:constructor, :args, :span) do
      include Base
    end
  end
end
