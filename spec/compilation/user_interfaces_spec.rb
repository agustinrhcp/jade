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

        expect(ShowTest.show_int(42)).to eql 'an int'
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

        expect(ShowTest.show_int(42)).to eql 'int'
        expect(ShowTest.show_str('hi')).to eql 'str'
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

        expect(ShowTest.show_int_via_helper(42)).to eql 'int'
      end
    end

    context 'inline lambda in an implementation' do
      let(:source) do
        <<~JADE
          module InlineImpl exposing (show_int, show_str)

          interface Show(a) with
            show : a -> String
          end


          implements Show(Int) with
            show: (n) -> { "int" }
          end


          implements Show(String) with
            show: (s) -> { "str" }
          end


          def show_int(n: Int) -> String
            show(n)
          end


          def show_str(s: String) -> String
            show(s)
          end
        JADE
      end

      it 'compiles and dispatches' do
        test_compiler.require('inline_impl', source)

        expect(InlineImpl.show_int(42)).to eql 'int'
        expect(InlineImpl.show_str('hi')).to eql 'str'
      end
    end

    context 'implementing for a qualified type' do
      let(:source) do
        <<~JADE
          module QualImpl exposing (tag_today)

          import Calendar


          interface Marker(a) with
            tag : a -> Int
          end


          implements Marker(Calendar.Date) with
            tag: (d) -> {
              d.year
            }
          end


          def tag_today -> Int
            tag(Calendar.from_calendar_date(2026, Calendar.Jan, 1))
          end
        JADE
      end

      it 'compiles and dispatches via the qualified type' do
        test_compiler.require('qual_impl', source)

        expect(QualImpl.tag_today).to eql 2026
      end
    end

    context 'bare reference whose type does not match the interface slot' do
      let(:source) do
        <<~JADE
          module BareMismatch exposing (run)

          interface Show(a) with
            show : a -> String
          end


          implements Show(Int) with
            show: identity
          end


          def run(n: Int) -> String
            show(n)
          end
        JADE
      end

      it 'reports an implementation type mismatch' do
        expect { test_compiler.require('bare_mismatch', source) }
          .to raise_error(CompilationError, /Implementation of .*Show\.show/)
      end
    end

    context 'bare reference to a function from another module' do
      let(:source) do
        <<~JADE
          module BareCrossModule exposing (run)

          interface Echo(a) with
            echo : a -> a
          end


          implements Echo(String) with
            echo: identity
          end


          def run(s: String) -> String
            echo(s)
          end
        JADE
      end

      it 'resolves identity to Basics.identity via lexical scope' do
        test_compiler.require('bare_cross_module', source)

        expect(BareCrossModule.run('hi')).to eql 'hi'
      end
    end
  end
end
