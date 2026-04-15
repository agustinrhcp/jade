require 'jade/interop/runtime'

module Tuple
  Tuple2 = Data.define(:_1, :_2) do
    def to_s = "(#{[_1, _2].map(&:to_s).join(', ')})"
  end

  Tuple3 = Data.define(:_1, :_2, :_3) do
    def to_s = "(#{[_1, _2, _3].map(&:to_s).join(', ')})"
  end

  Tuple4 = Data.define(:_1, :_2, :_3, :_4) do
    def to_s = "(#{[_1, _2, _3, _4].map(&:to_s).join(', ')})"
  end
end

module Basics
  GT = Data.define()
  EQ = Data.define()
  LT = Data.define()
end

module Jade

  module Runtime
    extend self
    extend Interop::Runtime

    INTRINSICS = {}
    @booted = false

    def boot!
      return if @booted
      @booted = true

      require "jade/stdlib/basics"
      require "jade/stdlib/string"
      require "jade/stdlib/list"
      require "jade/stdlib/tuple"
    end

    def intr(name)
      boot!
      INTRINSICS[name] || fail("Intrinsic #{name} does not exist")
    end

    def register(name, &block)
      INTRINSICS[name] = block
    end
  end
end
