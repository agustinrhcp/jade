require 'spec_helper'

require 'jade/runtime'

module Jade
  module Runtime
    describe '.curry' do
      let(:ctor) { Struct.new(:a, :b, :c) }

      it 'applies arguments one at a time' do
        f = Runtime.curry(ctor.method(:new), 3)
        expect(f.call(1).call(2).call(3)).to eq ctor.new(1, 2, 3)
      end

      it 'accepts several arguments per call' do
        f = Runtime.curry(ctor.method(:new), 3)
        expect(f.call(1, 2).call(3)).to eq ctor.new(1, 2, 3)
      end

      it 'is re-entrant — the same curried value is reusable' do
        f = Runtime.curry(ctor.method(:new), 3)
        expect(f.call(1).call(2).call(3)).to eq ctor.new(1, 2, 3)
        expect(f.call(4).call(5).call(6)).to eq ctor.new(4, 5, 6)
      end

      it 'returns the callable unchanged for arity 1' do
        one = ->(x) { x + 1 }
        expect(Runtime.curry(one, 1).call(41)).to eq 42
      end

      # The reason this helper exists rather than Method#curry: generated
      # decoders build a constructor once (Decode.succeed(Ctor.curry(n))) and
      # call it on every decode, and Ruby's Method#curry corrupts the heap
      # under GC compaction in that pattern (a near-null "try to mark T_NONE
      # object" SIGSEGV). Plain procs + an Array are GC-safe. The codegen
      # guard against regressing to Method#curry lives in
      # spec/compilation/constructor_curry_spec.rb.
    end
  end
end
