require 'spec_helper'

require 'jade'

module Jade
  describe Interop::Lowering do
    def int_sym
      Symbol::TypeApplication[Symbol::TypeRef['Basics', 'Int'], []]
    end

    def float_sym
      Symbol::TypeApplication[Symbol::TypeRef['Basics', 'Float'], []]
    end

    def bool_sym
      Symbol::TypeApplication[Symbol::TypeRef['Basics', 'Bool'], []]
    end

    def str_sym
      Symbol::TypeApplication[Symbol::TypeRef['String', 'String'], []]
    end

    def maybe_sym(param)
      Symbol::TypeApplication[Symbol::TypeRef['Maybe', 'Maybe'], [param]]
    end

    def list_sym(param)
      Symbol::TypeApplication[Symbol::TypeRef['List', 'List'], [param]]
    end

    let(:registry) do
      Stdlib.load(Registry.new)
    end

    subject { described_class.lower_symbol(symbol, registry).lowered_type }

    context 'an Int' do
      let(:symbol) { int_sym }

      it { is_expected.to eql 'int' }
    end

    context 'a Bool' do
      let(:symbol) { bool_sym }

      it { is_expected.to eql 'bool' }
    end

    context 'a Float' do
      let(:symbol) { float_sym }

      it { is_expected.to eql 'float' }
    end

    context 'a String' do
      let(:symbol) { str_sym  }

      it { is_expected.to eql 'string' }
    end

    context 'a Maybe(String)' do
      let(:symbol) do
        str_sym.then { maybe_sym(it) }
      end

      it { is_expected.to eql ['maybe', 'string'] }
    end

    context 'a List(Int)' do
      let(:symbol) do
        int_sym.then { list_sym(it) }
      end

      it { is_expected.to eql ['list', 'int'] }
    end

    context 'a Maybe(List(Int))' do
      let(:symbol) do
        int_sym.then { list_sym(it) }.then { maybe_sym(it) }
      end

      it { is_expected.to eql ['maybe', ['list', 'int']] }
    end
  end
end
