require 'spec_helper'

require 'jade/stdlib/basics'

module Jade
  module Stdlib
    describe Basics do
      describe 'its symbols' do
        subject { described_class.symbols.map(&:name) }

        it { is_expected.to include('Int') }
        it { is_expected.to include('Float') }
        it { is_expected.to include('Bool') }
        it { is_expected.to include('(+)') }
        it { is_expected.to include('(-)') }
        it { is_expected.to include('(*)') }
        it { is_expected.to include('(/)') }
      end

      describe 'its registered functions' do
        describe '(+)' do
          it 'registers it and works' do
            expect(Runtime.intr("Basics.(+)").call(1, 2)).to eql 3
          end
        end

        describe '(-)' do
          it 'registers it and works' do
            expect(Runtime.intr("Basics.(-)").call(2, 1)).to eql 1
          end
        end

        describe '(/)' do
          it 'registers it and works' do
            expect(Runtime.intr("Basics.(/)").call(4, 2)).to eql 2
          end
        end

        describe '(*)' do
          it 'registers it and works' do
            expect(Runtime.intr("Basics.(*)").call(2, 3)).to eql 6
          end
        end
      end
    end
  end
end
