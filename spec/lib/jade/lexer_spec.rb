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

      context 'tokenizing a float' do
        let(:text) do
          <<~JADE
            42.42
          JADE
        end

        it { is_expected.to have(1).item.and all(be_a(Token)) }
        its([0]) { is_expected.to be_token.of_type(:float).with('42.42').at(0...5) }
      end

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

    context 'bind' do
      let(:text) do
        <<~JADE
          some_var <- foo
        JADE
      end

      it { is_expected.to have(3).item.and all(be_a(Token)) }

      its([0]) { is_expected.to be_token.of_type(:identifier).with('some_var') }
      its([1]) { is_expected.to be_token.of_type(:bind) }
      its([2]) { is_expected.to be_token.of_type(:identifier).with('foo') }
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

    context 'operators' do
      let(:text) do
        <<~JADE
          12 + 12
        JADE
      end

      it { is_expected.to have(3).item.and all(be_a(Token)) }
      its([0]) { is_expected.to be_token.of_type(:int).with('12') }
      its([1]) { is_expected.to be_token.of_type(:plus).with('+') }
      its([2]) { is_expected.to be_token.of_type(:int).with('12') }

      context 'a chain of operators' do
        let(:text) do
          <<~JADE
            1 + 2 * 3 - 4 / 5
          JADE
        end

        it { is_expected.to have(9).item.and all(be_a(Token)) }
        its([0]) { is_expected.to be_token.of_type(:int).with('1') }
        its([1]) { is_expected.to be_token.of_type(:plus).with('+') }
        its([2]) { is_expected.to be_token.of_type(:int).with('2') }
        its([3]) { is_expected.to be_token.of_type(:star).with('*') }
        its([4]) { is_expected.to be_token.of_type(:int).with('3') }
        its([5]) { is_expected.to be_token.of_type(:minus).with('-') }
        its([6]) { is_expected.to be_token.of_type(:int).with('4') }
        its([7]) { is_expected.to be_token.of_type(:slash).with('/') }
        its([8]) { is_expected.to be_token.of_type(:int).with('5') }
      end
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

    context 'type def' do
      let(:text) do
        <<~JADE
          type Maybe(a) = Just(a) | Nothing
        JADE
      end

      it { is_expected.to have(12).item.and all(be_a(Token)) }
      its([0])  { is_expected.to be_token.of_type(:type).at(0...4) }
      its([1])  { is_expected.to be_token.of_type(:constant).with('Maybe').at(5...10) }
    end

    context 'module' do
      let(:text) do
        <<~JADE
          module Test exposing (hello)

          def hello(str: String) -> Bool
            String.is_empty(str)
          end
        JADE
      end

      it { is_expected.to have(22).item.and all(be_a(Token)) }
      its([0])  { is_expected.to be_token.of_type(:module).at(0...6) }
      its([1])  { is_expected.to be_token.of_type(:constant).with('Test').at(7...11) }
    end

    context 'if then else' do
      let(:text) do
        <<~JADE
          if String.is_empty("") then
            1
          else
            2
          end
        JADE
      end

      it { is_expected.to have(14).item.and all(be_a(Token)) }
      its([0])  { is_expected.to be_token.of_type(:if).at(0...2) }
      its([9])  { is_expected.to be_token.of_type(:then).at(23...27) }
      its([11])  { is_expected.to be_token.of_type(:else).at(32...36) }
    end

    context 'case of' do
      let(:text) do
        <<~JADE
          case 1 of
          _ then 2
          end
        JADE
      end

      it { is_expected.to have(7).item.and all(be_a(Token)) }
      its([0])  { is_expected.to be_token.of_type(:case).at(0...4) }
      its([2])  { is_expected.to be_token.of_type(:of).at(7...9) }
      its([3])  { is_expected.to be_token.of_type(:wildcard).at(10...11) }
      its([6])  { is_expected.to be_token.of_type(:end).at(19...22) }
    end

    context 'comments' do
      let(:text) do
        <<~JADE
          # this is a comment
        JADE
      end

      it { is_expected.to have(1).item.and all(be_a(Token)) }
      its([0])  { is_expected.to be_token.of_type(:comment).at(0...19) }
    end

    context 'interop interface' do
      let(:text) do
        <<~JADE
          uses Ruby::Mod with
            date : () -> Int
        JADE
      end

      it { is_expected.to have(11).item.and all(be_a(Token)) }
      its([0])  { is_expected.to be_token.of_type(:uses).at(0...4) }
      its([2])  { is_expected.to be_token.of_type(:coloncolon).at(9...11) }
      its([4])  { is_expected.to be_token.of_type(:with).at(15...19) }
    end
  end
end
