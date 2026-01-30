require 'spec_helper'

require 'jade'

module Jade
  describe Interop::Lowering do
    let(:registry) do
      Stdlib.load(Registry.new)
    end

    subject { described_class.lower_symbol(symbol, registry).lowered_type }

    context 'an Int' do
      let(:symbol) { Symbol::TypeRef['Basics', 'Int'] }

      it { is_expected.to eql 'int' }
    end

    context 'a Bool' do
      let(:symbol) { Symbol::TypeRef['Basics', 'Bool'] }

      it { is_expected.to eql 'bool' }
    end

    context 'a Float' do
      let(:symbol) { Symbol::TypeRef['Basics', 'Float'] }

      it { is_expected.to eql 'float' }
    end

    context 'a String' do
      let(:symbol) { Symbol::TypeRef['String', 'String'] }

      it { is_expected.to eql 'string' }
    end

    context 'a Maybe(String)' do
      let(:symbol) do
        Symbol::TypeApplication[Symbol::TypeRef['Maybe', 'Maybe'], [Symbol::TypeRef['String', 'String']]]
      end

      it { is_expected.to eql ['maybe', 'string'] }
    end

    context 'a List(Int)' do
      let(:symbol) do
        Symbol::TypeApplication[Symbol::TypeRef['List', 'List'], [Symbol::TypeRef['Basics', 'Int']]]
      end

      it { is_expected.to eql ['list', 'int'] }
    end

    context 'a Maybe(List(Int))' do
      let(:symbol) do
        Symbol::TypeRef['Basics', 'Int']
          .then { Symbol::TypeApplication[Symbol::TypeRef['List', 'List'], [it]] }
          .then { Symbol::TypeApplication[Symbol::TypeRef['Maybe', 'Maybe'], [it]] }
      end

      it { is_expected.to eql ['maybe', ['list', 'int']] }
    end
  end
end
