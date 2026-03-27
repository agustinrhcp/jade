require 'spec_helper'

require 'jade'

module Jade
  describe 'String' do
    include_context 'with test compiler'

    let(:pepe_source) do
      <<~JADE
        module Pepe exposing(str_to_int)

        def str_to_int(str: String) -> Maybe(Int)
          String.to_int(str)
        end
      JADE
    end

    before do
      test_compiler.require('pepe', pepe_source)
    end

    it 'works' do
      expect(Pepe.str_to_int.call('1')).to eql Maybe::Just[1]
      expect(Pepe.str_to_int.call('pepe')).to eql Maybe::Nothing[]
    end
  end
end
