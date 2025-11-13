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

    context 'function declaration' do
      let(:text) do
        <<~JADE
          def add(a: Int, b: Int) -> Int
            a
          end
        JADE
      end

      it { is_expected.to have(15).item.and all(be_a(Token)) }
      its([0])  { is_expected.to be_token.of_type(:def).at(0...3) }
      its([1])  { is_expected.to be_token.of_type(:identifier).with('add').at(4...7) }
      its([2])  { is_expected.to be_token.of_type(:lparen).at(7...8) }
      its([3])  { is_expected.to be_token.of_type(:identifier).with('a').at(8...9) }
      its([4])  { is_expected.to be_token.of_type(:colon).at(9...10) }
      its([5])  { is_expected.to be_token.of_type(:constant).with('Int').at(11...14) }
      its([6])  { is_expected.to be_token.of_type(:comma).at(14...15) }
      its([7])  { is_expected.to be_token.of_type(:identifier).with('b').at(16...17) }
      its([8])  { is_expected.to be_token.of_type(:colon).at(17...18) }
      its([9])  { is_expected.to be_token.of_type(:constant).with('Int').at(19...22) }
      its([10]) { is_expected.to be_token.of_type(:rparen).at(22...23) }
      its([11]) { is_expected.to be_token.of_type(:arrow).with('->').at(24...26) }
      its([12]) { is_expected.to be_token.of_type(:constant).with('Int').at(27...30) }
      its([13]) { is_expected.to be_token.of_type(:identifier).with('a').at(33...34) }
      its([14]) { is_expected.to be_token.of_type(:end).at(35...38) }
    end
  end
end
