require 'spec_helper'

require 'jade'

module Jade
  describe Interop::Lowering do
    include SymbolFactory

    let(:registry) { Stdlib.load(Registry.new) }
    let(:entry)    { Entry.empty('Test') }

    subject { described_class.validate(symbol, registry, entry).map(&:message) }

    context 'an Int is permitted' do
      let(:symbol) { type_sym('Basics', 'Int') }

      it { is_expected.to be_empty }
    end

    context 'a Maybe(List(Int)) is permitted' do
      let(:symbol) do
        type_sym('Basics', 'Int')
          .then { type_sym('List', 'List').with(args: [it]) }
          .then { type_sym('Maybe', 'Maybe').with(args: [it]) }
      end

      it { is_expected.to be_empty }
    end

    context 'a bare type variable is rejected' do
      let(:symbol) { Symbol::Variable['a', nil] }

      it { is_expected.to include('Type param (a) cannot be lowered for interop') }
    end

    context 'a type variable nested in a List arg is rejected' do
      let(:symbol) do
        Symbol::Variable['a', nil]
          .then { type_sym('List', 'List').with(args: [it]) }
      end

      it { is_expected.to include('Type param (a) cannot be lowered for interop') }
    end

    context 'a function used as a type is rejected' do
      let(:symbol) { Symbol.function_type([type_sym('Basics', 'Int')], type_sym('Basics', 'Int')) }

      it { is_expected.to include('Function (inline function type) cannot be lowered for interop') }
    end
  end
end
