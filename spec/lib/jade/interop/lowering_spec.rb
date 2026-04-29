require 'spec_helper'

require 'jade'

module Jade
  describe Interop::Lowering do
    include SymbolFactory

    let(:registry) { Stdlib.load(Registry.new) }
    let(:entry)    { Entry.empty('Test') }

    subject { described_class.lower_symbol(symbol, registry, entry).lowered_type }

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

    context 'a named struct resolved via entry (module not yet in registry)' do
      let(:struct) do
        Symbol::Struct.new(
          module_name: 'MyModule',
          name:        'Point',
          type_params: [],
          record_type: Symbol::RecordType.new(
            { 'x' => type_sym('Basics', 'Int'), 'y' => type_sym('Basics', 'Int') },
            nil
          ),
          decl_span: nil,
        )
      end

      let(:entry)  { Entry.empty('MyModule').define(struct) }
      let(:symbol) { type_sym('MyModule', 'Point') }

      subject { described_class.lower_symbol(symbol, registry, entry).lowered_type }

      it { is_expected.to eql({ 'x' => 'int', 'y' => 'int' }) }
    end

    context 'a union type (cannot be lowered)' do
      let(:entry)  { Entry.empty('MyModule') }
      let(:symbol) { type_sym('MyModule', 'Color') }

      subject { described_class.lower_symbol(symbol, registry, entry).errors.map(&:message) }

      it { is_expected.to include('Union (Color) cannot be lowered for interop') }
    end
  end
end
