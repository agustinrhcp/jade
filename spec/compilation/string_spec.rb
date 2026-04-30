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

  describe '++ operator' do
    include_context 'with test compiler'

    context 'on strings' do
      let(:source) do
        <<~JADE
          module Concat exposing (greet, join)

          def greet(name: String) -> String
            "Hello, " ++ name ++ "!"
          end

          def join(a: String, b: String, sep: String) -> String
            a ++ sep ++ b
          end
        JADE
      end

      before { test_compiler.require('concat', source) }

      it 'concatenates strings' do
        expect(Concat.greet.call('Alice')).to eql 'Hello, Alice!'
        expect(Concat.join.call('foo', 'bar', '-')).to eql 'foo-bar'
      end
    end

    context 'on lists' do
      let(:source) do
        <<~JADE
          module Concat exposing (combine)

          def combine(a: List(Int), b: List(Int)) -> List(Int)
            a ++ b
          end
        JADE
      end

      before { test_compiler.require('concat', source) }

      it 'concatenates lists' do
        expect(Concat.combine.call([1, 2], [3, 4])).to eql [1, 2, 3, 4]
        expect(Concat.combine.call([], [1])).to eql [1]
      end
    end
  end

  describe 'string escape sequences' do
    include_context 'with test compiler'

    let(:source) do
      <<~'JADE'
        module Escape exposing (newline, tab, backslash, quote)

        def newline() -> String
          "Hello\nWorld"
        end

        def tab() -> String
          "col1\tcol2"
        end

        def backslash() -> String
          "back\\slash"
        end

        def quote() -> String
          "say \"hi\""
        end
      JADE
    end

    before { test_compiler.require('escape', source) }

    it 'resolves \\n to a newline character' do
      expect(Escape.newline.call).to eql "Hello\nWorld"
    end

    it 'resolves \\t to a tab character' do
      expect(Escape.tab.call).to eql "col1\tcol2"
    end

    it 'resolves \\\\ to a backslash' do
      expect(Escape.backslash.call).to eql 'back\slash'
    end

    it 'resolves \\" to a double quote' do
      expect(Escape.quote.call).to eql 'say "hi"'
    end
  end
end
