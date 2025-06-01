require 'spec_helper'
require 'generator'

describe Generator do
  subject { described_class.generate(node) }

  context 'a simple bineray operation' do
    let(:node) { bin(lit(1), :+, var('x')) }
    it { is_expected.to eql '1 + x' }
  end

  context 'simple program' do
    let(:node) do
      prog(
        var_dec(:x, bin(lit(5), :*, lit(7))),
        bin(lit(1), :+, var('x'))
      )
    end

    it { is_expected.to eql "x = 5 * 7\n1 + x" }
  end
end
