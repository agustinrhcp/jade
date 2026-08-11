require 'spec_helper'

require 'jade'

module Jade
  describe Interop::DecodeError do
    let(:error) { Decode::WrongType['Int', 'String'] }

    context 'a value Ruby passed into a Jade function' do
      subject { described_class.new(error, 'forty').message }

      it { is_expected.to start_with('Ruby passed a value that failed to decode') }
      it { is_expected.not_to include('Port') }
    end

    context 'a value a port handed back' do
      subject { described_class.new(error, 'forty', source: :port_return).message }

      it { is_expected.to start_with('Port returned a value that failed to decode') }
    end

    context 'the default source' do
      subject { described_class.new(error, 'forty').source }

      it { is_expected.to eq(:argument) }
    end
  end

  describe Interop::Boundary do
    describe '.hash' do
      context 'string keys' do
        subject { described_class.hash('Person', { 'name' => 'Ada' }) }

        it { is_expected.to eq({ 'name' => 'Ada' }) }
      end

      context 'a Data instance' do
        let(:person) { ::Data.define(:name).new(name: 'Ada') }

        subject { described_class.hash('Person', person) }

        it { is_expected.to eq({ 'name' => 'Ada' }) }
      end

      context 'an empty hash' do
        subject { described_class.hash('Person', {}) }

        it { is_expected.to eq({}) }
      end

      context 'symbol keys' do
        def decode
          described_class.hash('Person', { name: 'Ada', age: 40 })
        end

        it 'names the mistake' do
          expect { decode }
            .to raise_error(Interop::SymbolKeys, /expects a Hash with string keys/)
        end

        it 'lists the offending keys' do
          expect { decode }.to raise_error(Interop::SymbolKeys, /:name, :age/)
        end

        it 'shows the fix' do
          expect { decode }
            .to raise_error(Interop::SymbolKeys, /try "name" rather than :name/)
        end
      end

      context 'mixed keys' do
        subject { described_class.hash('Person', { 'name' => 'Ada', age: 40 }) }

        it { is_expected.to eq({ 'name' => 'Ada', age: 40 }) }
      end

      context 'not a hash at all' do
        it 'reports the type it wanted' do
          expect { described_class.hash('Person', 42) }
            .to raise_error(Interop::DecodeError, /expected Person, got Int/)
        end
      end
    end
  end
end
