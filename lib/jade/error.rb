module Jade
  class Error
    attr_reader :entry, :span

    def initialize(entry:, span:, **rest)
      @entry = entry
      @span = span
    end

    def message
      fail NotImplementedError
    end
  end
end
