require 'spec_helper'

require 'jade'
require 'jade/module_loader'

module Jade
  describe 'Result.on_error' do
    include_context 'with test compiler'

    let(:source) do
      <<~JADE
        module Recovery exposing (passthrough, recovered)

        def recover(r: Result(Int, String)) -> Result(Int, Int)
          r |> Result.on_error((e) -> { Err(0) })
        end


        def passthrough -> Result(Int, Int)
          recover(Ok(1))
        end


        def recovered -> Result(Int, Int)
          recover(Err("boom"))
        end
      JADE
    end

    before do
      test_compiler.require('recovery', source)
    end

    it 'carries an Ok through into the new error type' do
      expect(Recovery::Internal.passthrough).to be_ok(1)
    end

    it 'recovers an Err into the new error type' do
      expect(Recovery::Internal.recovered).to be_err(0)
    end
  end
end
