require 'spec_helper'
require 'jade'
require 'jade/module_loader'

module Jade
  describe 'dictionary passing for polymorphic functions' do
    include_context 'with test compiler'

    it 'attaches constraint when return type wraps the type variable in a struct' do
      test_compiler.require('repro', <<~JADE)
        module Repro exposing(wrapped)

        interface Encoder(a) with
          encode : a -> String
        end

        implements Encoder(Int) with
          encode : encode_int
        end

        def encode_int(n: Int) -> String
          "int"
        end

        struct Box(a) = { value: String, tag: String }

        def wrapped(value: a) -> Box(a)
          Box(encode(value), "tag")
        end
      JADE

      build_root = test_compiler.instance_variable_get(:@build_root)
      compiled = File.read(File.join(build_root, 'repro.rb'))

      expect(compiled).to include('__wrapped__impl__')
      expect(compiled).to include('__dict0__')
    end

    it 'attaches constraints when two where-clauses on the same type variable are used in separate inner calls' do
      test_compiler.require('repro', <<~JADE)
        module Repro exposing(call_both)

        interface A(x) with f : x -> Int end
        interface B(x) with g : x -> Int end

        implements A(Int) with f : f_int end
        implements B(Int) with g : g_int end

        def f_int(n: Int) -> Int 1 end
        def g_int(n: Int) -> Int 2 end
        def add(a: Int, b: Int) -> Int a + b end

        def both(value: x) -> Int
          fx = f(value)
          gx = add(g(value), 0)
          fx + gx
        end

        def call_both() -> Int
          both(42)
        end
      JADE

      build_root = test_compiler.instance_variable_get(:@build_root)
      compiled = File.read(File.join(build_root, 'repro.rb'))

      # call_both is fully concrete — no impl-synthetic wrapper, no dict params.
      expect(compiled).not_to include('__call_both__impl__')

      # And it should run without an arity error.
      expect(Repro.call_both.call).to eql 3
    end
  end
end
