require 'spec_helper'

require 'jade'

module Jade
  describe Interop::Lowering do
    include SymbolFactory

    let(:registry) do
      Stdlib.load(Registry.new)
    end

    subject { described_class.lower_symbol(symbol, registry).lowered_type }

    context 'an Int' do
      let(:symbol) { type_sym('Basics', 'Int') }

      it { is_expected.to eql 'int' }
    end

    context 'a Bool' do
      let(:symbol) { type_sym('Basics', 'Bool') }

      it { is_expected.to eql 'bool' }
    end

    context 'a Float' do
      let(:symbol) { type_sym('Basics', 'Float') }

      it { is_expected.to eql 'float' }
    end

    context 'a String' do
      let(:symbol) { type_sym('String', 'String') }

      it { is_expected.to eql 'string' }
    end

    context 'a Maybe(String)' do
      let(:symbol) do
        type_sym('String', 'String')
          .then { type_sym('Maybe', 'Maybe').with(args: [it]) }
      end

      it { is_expected.to eql ['maybe', 'string'] }
    end

    context 'a List(Int)' do
      let(:symbol) do
        type_sym('Basics', 'Int')
          .then { type_sym('List', 'List').with(args: [it]) }
      end

      it { is_expected.to eql ['list', 'int'] }
    end

    context 'a Maybe(List(Int))' do
      let(:symbol) do
        type_sym('Basics', 'Int')
          .then { type_sym('List', 'List').with(args: [it]) }
          .then { type_sym('Maybe', 'Maybe').with(args: [it]) }
      end

      it { is_expected.to eql ['maybe', ['list', 'int']] }
    end
  end
end
