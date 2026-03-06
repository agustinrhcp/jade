require 'spec_helper'

require 'jade'
require 'jade/module_loader'

module Jade
  describe 'Interfaces' do
    include_context 'with test compiler'

    before do
      test_compiler.require('interface_test', source)
    end

    let(:source) do
      <<~JADE
        module InterfaceTest exposing (int_equality, bool_equality, int_inequality)

        def int_equality(int1: Int, int2: Int) -> Bool
          int1 == int2
        end

        def int_inequality(int1: Int, int2: Int) -> Bool
          int1 != int2
        end

        def bool_equality(int1: Bool, int2: Bool) -> Bool
          int1 == int2
        end
      JADE
    end

    it 'returns the value negated' do
      expect(InterfaceTest.int_equality.call(1, 2)).to be false
      expect(InterfaceTest.int_equality.call(1, 1)).to be true
      expect(InterfaceTest.int_inequality.call(1, 2)).to be true
      expect(InterfaceTest.int_inequality.call(1, 1)).to be false
      expect(InterfaceTest.bool_equality.call(true, false)).to be false
      expect(InterfaceTest.bool_equality.call(true, true)).to be true
    end
  end
end
