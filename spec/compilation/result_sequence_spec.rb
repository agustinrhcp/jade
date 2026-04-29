require 'spec_helper'

require 'jade'
require 'jade/module_loader'

module Jade
  describe 'Result.sequence' do
    include_context 'with test compiler'

    let(:source) do
      <<~JADE
        module Seq exposing (all_ok, with_err, first_err_wins)

        def all_ok() -> Result(List(Int), String)
          Result.sequence([Ok(1), Ok(2), Ok(3)])
        end

        def with_err() -> Result(List(Int), String)
          Result.sequence([Ok(1), Err("oops"), Ok(3)])
        end

        def first_err_wins() -> Result(List(Int), String)
          Result.sequence([Ok(1), Err("first"), Err("second")])
        end
      JADE
    end

    before do
      test_compiler.require('seq', source)
    end

    it 'collects all Oks into a list' do
      expect(Seq.all_ok.call).to eql Result::Ok[[1, 2, 3]]
    end

    it 'returns the error when any element is Err' do
      expect(Seq.with_err.call).to eql Result::Err['oops']
    end

    it 'returns the first error encountered' do
      expect(Seq.first_err_wins.call).to eql Result::Err['first']
    end
  end
end
