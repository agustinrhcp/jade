require 'spec_helper'

require 'lexer'

describe Lexer do
  subject(:tokens) { Lexer.scan(code) }

  context 'literals' do
    context 'int' do
      let(:code) { '1' }

      it { is_expected.to have_tokenized(:int).with(1) }
    end

    context 'boolean' do
      let(:code) { 'True' }

      it { is_expected.to have_tokenized(:bool).with(true) }

      context 'false' do
        it { is_expected.to have_tokenized(:bool).with(false) }
      end
    end

    context 'strings' do
      let(:code) { '"Hello!"' }

      it { is_expected.to have_tokenized(:string).with('Hello!') }
    end
  end

  context 'identifier' do
    let(:code) { 'pepe' }

    it { is_expected.to have_tokenized(:identifier).with('pepe') }
  end

  context 'operators' do
    context '+' do
      let(:code) { '+' }

      it { is_expected.to have_tokenized(:plus).with('+') }
    end

    context '-' do
      let(:code) { '-' }

      it { is_expected.to have_tokenized(:minus).with('-') }
    end

    context '*' do
      let(:code) { '*' }

      it { is_expected.to have_tokenized(:star).with('*') }
    end

    context '/' do
      let(:code) { '/' }

      it { is_expected.to have_tokenized(:slash).with('/') }
    end

    context 'comparison' do
      context '==' do
        let(:code) { '==' }

        it { is_expected.to have_tokenized(:eq).with('==') }
      end

      context '!=' do
        let(:code) { '!=' }

        it { is_expected.to have_tokenized(:not_eq).with('!=') }
      end

      context '<' do
        let(:code) { '<' }

        it { is_expected.to have_tokenized(:lt).with('<') }
      end

      context '<=' do
        let(:code) { '<=' }

        it { is_expected.to have_tokenized(:lte).with('<=') }
      end

      context '>' do
        let(:code) { '>' }

        it { is_expected.to have_tokenized(:gt).with('>') }
      end

      context '>=' do
        let(:code) { '>=' }

        it { is_expected.to have_tokenized(:gte).with('>=') }
      end
    end
  end

  context 'a + b' do
    let(:code) { 'a + b' }

    its(:size) { is_expected.to be 3 }
    it { is_expected.to have_tokenized(:identifier).with('a') }
    it { is_expected.to have_tokenized(:identifier).with('b') }
    it { is_expected.to have_tokenized(:plus) }
  end

  context 'a variable declaration' do
    let(:code) { 'let x = 5' }

    its(:size) { is_expected.to be 4 }
    it { is_expected.to have_tokenized(:let) }
    it { is_expected.to have_tokenized(:identifier).with('x') }
    it { is_expected.to have_tokenized(:assign) }
    it { is_expected.to have_tokenized(:int).with(5) }
  end

  context 'a function definition' do
    let(:code) do
      <<~CODE
        def double(a: Int) -> Int
          a * 2
        end
      CODE
    end

    its(:size) { is_expected.to eql 13 }

    it { is_expected.to have_tokenized(:def).on(line: 1, column: 1) }
    it { is_expected.to have_tokenized(:identifier).with('double') }
    it { is_expected.to have_tokenized(:arrow) }
    it { is_expected.to have_tokenized(:identifier).with('a').on(line: 2, column: 1) }
    it { is_expected.to have_tokenized(:star).on(line: 2, column: 3) }
    it { is_expected.to have_tokenized(:int).on(line: 2, column: 5).with(2) }
    it { is_expected.to have_tokenized(:end).on(line: 3, column: 1) }
  end
end
