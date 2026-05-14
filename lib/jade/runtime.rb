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

  module Bytes
    Bytes = Data.define(:bin) do
      def to_s = "Bytes(#{bin.bytesize})"
    end

    LE = Data.define()
    BE = Data.define()

    module Encode
      Encoder = Data.define(:bin)
    end

    module Decode
      Decoder = Data.define(:run)
    end
  end

  module Dict
    Dict = Data.define(:hash) do
      def to_s
        pairs = hash.map { |k, v| "#{k}: #{v}" }.join(', ')
        "Dict(#{pairs})"
      end
    end
  end

  module Runtime
    extend self
    extend Interop::Runtime

    INTRINSICS = {}
    IMPLEMENTATIONS = {}
    IMPL_CACHE = {}
    RECORD_CLASSES = {}
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
      require "jade/stdlib/bytes"
      require "jade/stdlib/bytes/encode"
      require "jade/stdlib/bytes/decode"
      require "jade/stdlib/dict"
    end

    def intr(name)
      boot!
      INTRINSICS[name] || fail("Intrinsic #{name} does not exist")
    end

    def register(name, &block)
      INTRINSICS[name] = block
    end

    # Memoized class for anonymous record literals. Without this, every
    # `{a: 1, b: 2}` expression evaluated in a hot loop would call
    # `Data.define(:a, :b)` and allocate a fresh anonymous class, defeating
    # YJIT's inline cache on every subsequent property access.
    def record(*keys)
      RECORD_CLASSES[keys] ||= Data.define(*keys)
    end

    def register_impl(interface_name, ruby_class, functions)
      IMPLEMENTATIONS[[interface_name, ruby_class]] = functions
      IMPL_CACHE.clear
    end

    # Returns a hash of fn_name => callable for the impl of `interface_name`
    # on `value`'s class. Results are cached: the same key returns the same
    # hash object across calls, so a hot polymorphic call site doesn't
    # re-allocate per invocation. Cache is invalidated whenever
    # `register_impl` adds or replaces an entry.
    def impl_for(interface_name, value)
      boot!
      key = [interface_name, value.class]
      IMPL_CACHE[key] ||= begin
        raw = IMPLEMENTATIONS[key] || fail("No implementation of #{interface_name} for #{value.class}")
        raw.any? { |_, v| v.is_a?(::String) } \
          ? raw.transform_values { |v| v.is_a?(::String) ? intr(v) : v }
          : raw
      end
    end
  end
end
