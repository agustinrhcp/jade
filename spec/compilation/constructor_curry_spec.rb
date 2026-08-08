require 'spec_helper'

require 'jade'
require 'jade/module_loader'

module Jade
  describe 'constructor codegen — curry safety' do
    include_context 'with test compiler'

    # Regression: a curried constructor built once and called on every
    # decode used to corrupt the heap under GC compaction when the curry
    # came from Ruby's Method#curry (a near-null "try to mark T_NONE
    # object" SIGSEGV). Derived record decoders no longer curry at all —
    # `Decode.record` applies every field in one call — so the hazard is
    # gone by construction here; the assertion stands for the constructors
    # that are still curried elsewhere. A Calendar.Date field forces the
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

    it 'never builds a constructor with Method#curry' do
      expect(test_compiler.generated_source('m')).not_to include('.method(:[]).curry')
    end

    it 'applies the derived record constructor in one uncurried call' do
      generated = test_compiler.generated_source('m')
      expect(generated).to include('Jade::Runtime.intr("Decode.record")')
      expect(generated).to include('::M::P')
    end

    it 'still decodes the record across the boundary' do
      expect(M.day_of({ 'amount' => 42, 'on' => '2026-06-17' })).to eq 42
    end
  end
end
