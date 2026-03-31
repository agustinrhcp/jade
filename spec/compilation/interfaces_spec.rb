require 'spec_helper'

require 'jade'
require 'jade/module_loader'

module Jade
  describe 'Interfaces' do
    include_context 'with test compiler'

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
      test_compiler.require('interface_test', source)
      expect(InterfaceTest.int_equality.call(1, 2)).to be false
      expect(InterfaceTest.int_equality.call(1, 1)).to be true
      expect(InterfaceTest.int_inequality.call(1, 2)).to be true
      expect(InterfaceTest.int_inequality.call(1, 1)).to be false
      expect(InterfaceTest.bool_equality.call(true, false)).to be false
      expect(InterfaceTest.bool_equality.call(true, true)).to be true
    end

    context 'equality on functions' do
      let(:source) do
        <<~JADE
          module InterfaceTest exposing (fn_equality)

          def fn_equality() -> Bool
            one = (a, b) -> { a + b }
            one == one
          end
        JADE
      end

      it 'fails, because functions cant be compared' do
        expect { test_compiler.require('interface_test', source) }
          .to raise_error(RuntimeError, /No implementation of Basics.Eq for \(Int, Int\) -> Int/)
      end
    end

    context 'constraint propagation' do
      let(:source) do
        <<~JADE
          module InterfaceTest exposing (compare)

          def compare(a: Int, b: Int) -> Bool
            eq(a, b)
          end

          def eq(a: a, b: a) -> Bool
            a == b
          end
        JADE
      end

      it 'propagates constraints through functions' do
        test_compiler.require('interface_test', source)

        expect(InterfaceTest.compare.call(1, 1)).to be true
      end
    end

    context 'polymorphic equality' do
      let(:source) do
        <<~JADE
          module InterfaceTest exposing (int_eq, bool_eq)

          def poly_eq(a: a, b: a) -> Bool
            a == b
          end

          def int_eq(a: Int, b: Int) -> Bool
            poly_eq(a, b)
          end

          def bool_eq(a: Bool, b: Bool) -> Bool
            poly_eq(a, b)
          end
        JADE
      end

      it 'works for ints and bools' do
        test_compiler.require('interface_test', source)

        expect(InterfaceTest.int_eq.call(1, 1)).to be true
        expect(InterfaceTest.bool_eq.call(true, true)).to be true
      end
    end
  end
end
