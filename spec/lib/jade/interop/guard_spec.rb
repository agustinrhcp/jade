require 'spec_helper'

require 'jade/interop/guard'

module Jade
  describe Interop::Guard do
    subject { described_class.guard(ruby_value, bridge_type) }

    context 'an Int when expecting int' do
      let(:ruby_value) { 10 }
      let(:bridge_type) { 'int' }

      it { is_expected.to eql 10 }
    end

    context 'a Float when expecting float' do
      let(:ruby_value) { 10.0 }
      let(:bridge_type) { 'float' }

      it { is_expected.to eql 10.0 }
    end

    context 'a Hash' do
      let(:ruby_value) { { some_float: 10.0 } }
      let(:bridge_type) { { 'some_float': 'float' } }

      it { is_expected.to be_a(Data).and have_attributes(some_float: 10.0) }

      context 'without an expected key' do
        let(:ruby_value) { {} }

        it 'raises' do
          expect { subject }
            .to raise_error(Interop::Guard::Error, /Expected Hash with key some_float, got {}/)
        end
      end
    end

    context 'a nil value' do
      let(:ruby_value) { nil }
      let(:bridge_type) { 'bool' }

      it 'raises' do
        expect { subject }
          .to raise_error(Interop::Guard::Error, /Expected non nil value true or false, got nil/)
      end

      context 'expecting a maybe' do
        let(:bridge_type) { ['maybe', 'bool'] }

        it { is_expected.to be_a(Maybe::Nothing) }
      end
    end

    context 'a Float when expecting Int' do
      let(:ruby_value) { 10.0 }
      let(:bridge_type) { 'int' }

      it 'raises' do
        expect { subject }
          .to raise_error(Interop::Guard::Error, /Expected Integer, got 10.0 \(Float\)/)
      end
    end
  end
end
