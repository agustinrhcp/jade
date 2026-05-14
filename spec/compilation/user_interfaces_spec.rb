require 'spec_helper'

require 'jade'
require 'jade/module_loader'

module Jade
  describe 'User-defined interfaces' do
    include_context 'with test compiler'

    context 'exposing the interface and its function' do
      let(:source) do
        <<~JADE
          module ShowTest exposing (Show, show)

          interface Show(a) with
            show : a -> String
          end

          implements Show(Int) with
            show: int_show
          end

          def int_show(n: Int) -> String
            "int"
          end
        JADE
      end

      it 'compiles' do
        expect { test_compiler.require('show_test', source) }.not_to raise_error
      end
    end

    context 'declaring and implementing for a single type' do
      let(:source) do
        <<~JADE
          module ShowTest exposing (show_int)

          interface Show(a) with
            show : a -> String
          end

          implements Show(Int) with
            show: int_show
          end

          def int_show(n: Int) -> String
            "an int"
          end

          def show_int(n: Int) -> String
            show(n)
          end
        JADE
      end

      it 'dispatches show to the Int implementation' do
        test_compiler.require('show_test', source)

        expect(ShowTest.show_int.call(42)).to eql 'an int'
      end
    end

    context 'polymorphic dispatch over two types' do
      let(:source) do
        <<~JADE
          module ShowTest exposing (show_int, show_str)

          interface Show(a) with
            show : a -> String
          end

          implements Show(Int) with
            show: int_show
          end

          implements Show(String) with
            show: str_show
          end

          def int_show(n: Int) -> String
            "int"
          end

          def str_show(s: String) -> String
            "str"
          end

          def show_int(n: Int) -> String
            show(n)
          end

          def show_str(s: String) -> String
            show(s)
          end
        JADE
      end

      it 'dispatches by type' do
        test_compiler.require('show_test', source)

        expect(ShowTest.show_int.call(42)).to eql 'int'
        expect(ShowTest.show_str.call('hi')).to eql 'str'
      end
    end

    context 'constraint propagation through user-defined interfaces' do
      let(:source) do
        <<~JADE
          module ShowTest exposing (show_int_via_helper)

          interface Show(a) with
            show : a -> String
          end

          implements Show(Int) with
            show: int_show
          end

          def int_show(n: Int) -> String
            "int"
          end

          def helper(x: a) -> String
            show(x)
          end

          def show_int_via_helper(n: Int) -> String
            helper(n)
          end
        JADE
      end

      it 'propagates the Show constraint through helper' do
        test_compiler.require('show_test', source)

        expect(ShowTest.show_int_via_helper.call(42)).to eql 'int'
      end
    end
  end
end
