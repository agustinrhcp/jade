require 'spec_helper'

require 'jade/lexer'

module Jade
  describe Lexer do
    let(:source) do
      Source.new(uri: 'test', text:)
    end

    subject { Lexer.tokenize(source) }

    context 'literals' do
      let(:text) do
        <<~JADE
          42
        JADE
      end

      it { is_expected.to have(1).item.and all(be_a(Token)) }
      its([0]) { is_expected.to be_token.of_type(:int).with('42').at(0...2) }

      describe 'tokenizing a string' do
        let(:text) do
          <<~JADE
            "Hello"
          JADE
        end

        it { is_expected.to have(3).item.and all(be_a(Token)) }
        its([0]) { is_expected.to be_token.of_type(:quote).with('"').at(0...1) }
        its([1]) { is_expected.to be_token.of_type(:string_chunk).with('Hello').at(1...6) }
        its([2]) { is_expected.to be_token.of_type(:quote).with('"').at(6...7) }

        context 'when it is malformed' do
          let(:text) do
            <<~JADE
              "Hello
            JADE
          end

          it { is_expected.to have(2).item.and all(be_a(Token)) }
          its([0]) { is_expected.to be_token.of_type(:quote).with('"').at(0...1) }
          its([1]) { is_expected.to be_token.of_type(:string_chunk).with('Hello').at(1...6) }
        end
      end
    end

    context 'assignment' do
      let(:text) do
        <<~JADE
          some_var = 42
        JADE
      end

      it { is_expected.to have(3).item.and all(be_a(Token)) }

      its([0]) { is_expected.to be_token.of_type(:identifier).with('some_var') }
      its([1]) { is_expected.to be_token.of_type(:assign) }
      its([2]) { is_expected.to be_token.of_type(:int).with('42') }
    end

    context 'variables' do
      let(:text) do
        <<~JADE
          some_var
        JADE
      end

      it { is_expected.to have(1).item.and all(be_a(Token)) }
      its([0]) { is_expected.to be_token.of_type(:identifier).with('some_var').at(0...8) }
    end
  end
end
