require 'jade/interop/runtime'

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
