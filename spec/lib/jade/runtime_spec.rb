require 'spec_helper'

require 'jade/runtime'

module Jade
  # A variant with no fields carries nothing to tell two instances apart,
  # so `compare` allocating a fresh `GT` per call was pure waste.
  describe '.nullary' do
    let(:kind) do
      Jade.nullary do
        def tagged?
          true
        end
      end
    end

    it 'hands back the same object every time' do
      expect(kind[]).to be kind.new
    end

    it 'keeps the methods defined on it' do
      expect(kind[].tagged?).to be true
    end

    it 'still matches its class' do
      klass = kind
      matched = case kind[]
                in ^klass then true
                end

      expect(matched).to be true
    end

    it 'covers the variants the runtime defines itself' do
      expect(Basics::GT[]).to be Basics::GT[]
    end
  end

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
