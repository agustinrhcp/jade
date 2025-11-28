require 'spec_helper'

require 'jade/source'

module Jade
  describe Source do
    describe '.load' do
      let(:uri) { 'maybe.jd' }

      subject { described_class.load('src', uri) }

      before { allow(File).to receive(:read) { 'some jade code' } }

      it { is_expected.to be_a(Source) }

      its(:uri) { is_expected.to eql uri }
      its(:text) { is_expected.to eql 'some jade code' }
      its(:to_module_name) { is_expected.to eql 'Maybe' }

      it 'reads the file' do
        expect(File).to receive(:read).with('src/maybe.jd')
        subject
      end
    end

    describe '.load_from_module_name' do
      let(:module_name) { 'Maybe' }

      subject { described_class.load_from_module_name('src', module_name) }

      before { allow(File).to receive(:read) { 'some jade code' } }

      it { is_expected.to be_a(Source) }

      its(:uri) { is_expected.to eql 'maybe.jd' }
      its(:text) { is_expected.to eql 'some jade code' }
      its(:to_module_name) { is_expected.to eql 'Maybe' }

      it 'reads the file' do
        expect(File).to receive(:read).with('src/maybe.jd')
        subject
      end
    end
  end
end
