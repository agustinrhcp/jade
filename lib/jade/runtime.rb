require 'jade/interop/runtime'
require 'jade/decode'

module Jade
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

  module Runtime
    extend self
    extend Interop::Runtime

    INTRINSICS = {}
    IMPLEMENTATIONS = {}
    @booted = false

    def boot!
      return if @booted
      @booted = true

      require "jade/stdlib/basics"
      require "jade/stdlib/string"
      require "jade/stdlib/list"
      require "jade/stdlib/tuple"
      require "jade/stdlib/task"
      require "jade/stdlib/decode"
      require "jade/stdlib/encode"
    end

    def intr(name)
      boot!
      INTRINSICS[name] || fail("Intrinsic #{name} does not exist")
    end

    def register(name, &block)
      INTRINSICS[name] = block
    end

    def register_impl(interface_name, ruby_class, functions)
      IMPLEMENTATIONS[[interface_name, ruby_class]] = functions
    end

    def impl_for(interface_name, value)
      boot!
      IMPLEMENTATIONS[[interface_name, value.class]]
        .then { it || fail("No implementation of #{interface_name} for #{value.class}") }
        .transform_values { |v| v.is_a?(::String) ? intr(v) : v }
    end
  end
end
