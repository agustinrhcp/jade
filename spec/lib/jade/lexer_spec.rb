require 'spec_helper'

require 'jade/lexer'

module Jade
  describe Lexer do
    let(:source) do
      text =<<~JADE
        42
      JADE

      Source.new(uri: 'test', text:)
    end

    subject { Lexer.tokenize(source) }

    it { is_expected.to have(1).item.and all(be_a(Token)) }

    describe 'the returned token' do
      subject { super().first }

      its(:type)  { is_expected.to eql :int }
      its(:value) { is_expected.to eql '42' }
      its(:range) { is_expected.to eql 0...2 }
    end
  end
end
