require 'spec_helper'

require 'jade'
require 'jade/module_loader'

module Jade
  describe 'Char is Comparable' do
    include_context 'with test compiler'

    before do
      test_compiler.require(source)
    end

    let(:source) do
      <<~JADE
        module Chars exposing (before?, sorted)

        def before?(a: Char, b: Char) -> Bool
          a < b
        end


        def sorted(cs: List(Char)) -> List(Char)
          List.sort(cs)
        end
      JADE
    end

    it 'orders by code point' do
      expect(Chars::Internal.before?('a', 'b')).to be true
      expect(Chars::Internal.before?('b', 'a')).to be false
      expect(Chars::Internal.before?('A', 'a')).to be true
    end

    it 'sorts a list' do
      expect(Chars::Internal.sorted(%w[c a b])).to eql %w[a b c]
    end
  end
end
