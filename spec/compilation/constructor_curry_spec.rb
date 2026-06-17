require 'spec_helper'

require 'jade'
require 'jade/module_loader'

module Jade
  describe 'constructor codegen — curry safety' do
    include_context 'with test compiler'

    # Regression: an auto-derived record decoder that runs through the Desc
    # interpreter builds the constructor once and calls it on every decode
    # (Decode.succeed(Ctor.curry(n)) threaded through and_map). Ruby's
    # Method#curry corrupts the heap under GC compaction in that pattern
    # (a near-null "try to mark T_NONE object" SIGSEGV). It must be built via
    # the GC-safe Jade::Runtime.curry. A Calendar.Date field forces the
    # interpreter boundary path (it can't be specialized inline).
    let(:source) do
      <<~JADE
        module M exposing (day_of)

        import Calendar


        struct P = {
          amount: Int,
          on: Calendar.Date
        }


        def day_of(p: P) -> Int
          p.amount
        end
      JADE
    end

    before { test_compiler.require('m', source) }

    it 'builds the constructor via Jade::Runtime.curry, never Method#curry' do
      generated = test_compiler.generated_source('m')
      expect(generated).to include('Jade::Runtime.curry')
      expect(generated).not_to include('.method(:[]).curry')
    end

    it 'still decodes the record across the boundary' do
      expect(M.day_of({ 'amount' => 42, 'on' => '2026-06-17' })).to eq 42
    end
  end
end
