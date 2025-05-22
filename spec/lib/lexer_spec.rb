require 'spec_helper'

require 'lexer'

describe Lexer do
  subject(:tokens) { Lexer.scan(code) }

  context 'a + b' do
    let(:code) { 'a + b' }

    its(:size) { is_expected.to be 3 }
    it { is_expected.to have_tokenized(:identifier).with('a') }
    it { is_expected.to have_tokenized(:identifier).with('b') }
    it { is_expected.to have_tokenized(:plus) }
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
