require 'jade/debug'
require 'base64'

require 'jade/interop/runtime'
require 'jade/decode'
require 'jade/interop/boundary'

module Jade
  module Records; end

  # A variant with no fields carries no state, so every construction can
  # hand back the same object. Prepended to the class's singleton so
  # `super` still reaches the real constructor the first time.
  module Nullary
    def new
      @instance ||= super
    end

    def []
      @instance ||= super
    end
  end

  def self.nullary(&block)
    Data.define
      .tap { it.class_eval(&block) if block }
      .tap { it.singleton_class.prepend(Nullary) }
  end

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
    GT = Jade.nullary
    EQ = Jade.nullary
    LT = Jade.nullary
  end

  # Compiled code calls `a.compare(b)`; natives ship `<=>` not `compare`.
  # Guarded so a future Ruby or third-party `compare` wins — clobbering
  # would silently swap semantics.
  [Integer, Float, ::String].each do |klass|
    next if klass.method_defined?(:compare)

    klass.class_eval do
      define_method(:compare) do |other|
        case self <=> other
        when -1 then Basics::LT[]
        when 0  then Basics::EQ[]
        when 1  then Basics::GT[]
        end
      end
    end
  end

  module Bytes
    Bytes = Data.define(:bin) do
      def to_s = "Bytes(#{bin.bytesize})"
      def +(other) = Bytes.new(bin + other.bin)
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

  module Set
    Set = Data.define(:hash) do
      def to_s = "Set(#{hash.keys.join(', ')})"
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

    # In dependency order: a module's `import` names the constant of another.
    STDLIB = %w[
      basics maybe number tuple list char string result task dict set
      decode decode/params encode bytes show debug
    ].freeze

    def boot!
      return if @booted
      @booted = true

      require 'jade/stdlib/intrinsics'
      Stdlib::Intrinsics.runtime_only! unless defined?(Jade::Frontend)

      STDLIB.each { require_relative "stdlib/#{it}" }
    end

    def intr(name)
      boot!
      INTRINSICS[name] || fail("Intrinsic #{name} does not exist")
    end

    # Hand-rolled currying for generated constructors. Ruby's Method#curry
    # corrupts the heap under GC compaction (the GC marks a T_NONE object
    # while a curried call is in flight) when a curried proc is built once
    # and called repeatedly — which is exactly the decoder applicative path
    # (Decode.succeed(Ctor.curry(n)) threaded through Decode.and_map). Plain
    # procs accumulating into an Array are GC-safe.
    def curry(fn, arity)
      return fn if arity <= 1

      build = ->(acc) {
        ->(*xs) {
          (acc + xs).then do |args|
            args.length >= arity ? fn.call(*args) : build.call(args)
          end
        }
      }
      build.call([])
    end

    def register(name, &block)
      INTRINSICS[name] = block
    end

    # Memoized class for anonymous record literals. Without this, every
    # `{a: 1, b: 2}` expression evaluated in a hot loop would call
    # `Data.define(:a, :b)` and allocate a fresh anonymous class, defeating
    # YJIT's inline cache on every subsequent property access.
    # Named, so the first module to assign it doesn't lend it a name
    # pointing at an unrelated module.
    def record(*keys)
      RECORD_CLASSES[keys] ||= Data
        .define(*keys)
        .tap { Jade::Records.const_set(:"Record_#{keys.join('_')}", it) }
    end

    def register_impl(interface_name, ruby_class, functions)
      IMPLEMENTATIONS[[interface_name, ruby_class]] = functions
      IMPL_CACHE.clear
    end

    # Cached per [interface_name, value.class]; `register_impl` invalidates.
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
