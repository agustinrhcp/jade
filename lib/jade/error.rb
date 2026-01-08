module Jade
  class Error
    def initialize(entry:, span:, **rest)
      @entry = entry
      @span = span
    end

    def message
      fail NotImplementedError
    end
  end
end
