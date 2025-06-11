require 'spec_helper'

require 'compiler'

describe Compiler do
  subject { described_class.compile(source_code) }

  context 'a function definition' do
    let(:source_code) do
      <<~JADE
        def add(a: Int, b: Int) -> Int
          a + b
        end
      JADE
    end

    it { is_expected.to eql "def add(a, b)\n  a + b\nend" }
  end

  context 'a type definition' do
    let(:source_code) do
      <<~JADE
        type User = { name: String, age: Int }
      JADE
    end

    it { is_expected.to eql "User = Data.define(:name, :age)" }
  end
end
