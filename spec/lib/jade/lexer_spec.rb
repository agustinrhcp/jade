require 'spec_helper'

require 'jade/lexer'

module Jade
  describe Lexer do
    let(:text) do
      <<~JADE
        42
      JADE
    end

    let(:source) do
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

    describe 'tokenizing a string' do
      let(:text) do
        <<~JADE
          "Hello"
        JADE
      end

      it { is_expected.to have(3).item.and all(be_a(Token)) }

      context 'when it is malformed' do
        let(:text) do
          <<~JADE
            "Hello
          JADE
        end

        it { is_expected.to have(2).item.and all(be_a(Token)) }

        describe "the string chunk" do
          subject { super().last }

          its(:value) { is_expected.to eql "Hello" }
        end
      end
    end
  end
end
