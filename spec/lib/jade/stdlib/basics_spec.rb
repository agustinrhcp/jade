require 'spec_helper'

require 'jade'

module Jade
  module Stdlib
    describe Basics do
      describe 'its symbols' do
        subject do
          described_class
            .symbols
            .reject { it.is_a?(Symbol::Implementation) }
            .map(&:name)
        end

        it { is_expected.to include('Int') }
        it { is_expected.to include('Float') }
        it { is_expected.to include('Bool') }
        it { is_expected.to include('(/)') }
        it { is_expected.to include('(||)') }
        it { is_expected.to include('(&&)') }
      end
    end
  end
end
