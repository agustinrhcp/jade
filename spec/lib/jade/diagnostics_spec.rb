require 'spec_helper'

require 'jade/source'
require 'jade/diagnostics'

module Jade
  describe Diagnostics::List do
    let(:source) { Source.new(uri: 'test.jd', text: "x = 1\n") }
    let(:span) { 0...5 }

    describe '.empty' do
      subject { described_class.empty }

      it { is_expected.to be_empty }
      it { is_expected.not_to be_any_errors }
      its(:items) { is_expected.to be_empty }
    end

    describe '#error' do
      subject(:diagnostics) do
        described_class.empty.error('something went wrong', source:, span:, label: 'here')
      end

      it { is_expected.not_to be_empty }
      it { is_expected.to be_any_errors }
      its(:items) { is_expected.to have(1).item }

      describe 'the diagnostic' do
        subject { diagnostics.items.first }

        it { is_expected.to be_a(Diagnostics::Diagnostic) }
        it { is_expected.to be_error }
        its(:message) { is_expected.to eq('something went wrong') }
        its(:severity) { is_expected.to eq(:error) }

        describe 'primary label' do
          subject { diagnostics.items.first.primary }

          its(:source) { is_expected.to eq(source) }
          its(:span) { is_expected.to eq(span) }
          its(:message) { is_expected.to eq('here') }
        end
      end
    end

    describe '#note and #help' do
      subject(:annotations) do
        described_class
          .empty
          .error('oops', source:, span:)
          .note('this is a note')
          .help('try this instead')
          .items
          .first
          .annotations
      end

      it { is_expected.to have(2).items }
      it do
        is_expected.to eq([
          Diagnostics::Annotation[:note, 'this is a note'],
          Diagnostics::Annotation[:help, 'try this instead'],
        ])
      end

      context 'on an empty list' do
        it 'is a no-op' do
          described_class.empty.note('ignored').then do |result|
            expect(result).to eq(described_class.empty)
          end
        end
      end
    end

    describe '#add' do
      let(:diagnostic) do
        Diagnostics::Diagnostic.error('oops', primary: Diagnostics::Label[source, span, nil])
      end

      subject { described_class.empty.add(diagnostic) }

      its(:items) { is_expected.to eq([diagnostic]) }
    end

    describe '#merge' do
      let(:a) { described_class.empty.error('first', source:, span:) }
      let(:b) { described_class.empty.error('second', source:, span:) }

      subject { a.merge(b) }

      its(:items) { is_expected.to have(2).items }
    end

    describe '#to_result' do
      context 'when there are errors' do
        subject { described_class.empty.error('oops', source:, span:).to_result(:value) }

        it { is_expected.to be_a(Err) }
      end

      context 'when there are no errors' do
        subject { described_class.empty.to_result(:value) }

        it { is_expected.to eq(Ok.new(:value)) }
      end
    end

    describe 'immutability' do
      it 'does not mutate the original when adding an error' do
        original = described_class.empty
        _updated = original.error('oops', source:, span:)
        expect(original).to be_empty
      end

      it 'does not mutate the original when adding a note' do
        original = described_class.empty.error('oops', source:, span:)
        _updated = original.note('a note')
        expect(original.items.first.annotations).to be_empty
      end
    end
  end
end
