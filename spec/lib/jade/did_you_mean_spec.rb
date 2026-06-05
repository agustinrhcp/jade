require 'spec_helper'

require 'jade/did_you_mean'

module Jade
  describe DidYouMean do
    describe '.suggest' do
      it 'returns closest matches' do
        expect(DidYouMean.suggest('helpr', %w[helper map filter])).to include('helper')
      end

      it 'returns at most `max` suggestions' do
        expect(DidYouMean.suggest('h', %w[helper helmet hand head], max: 2).size).to be <= 2
      end

      it 'returns empty when nothing close' do
        expect(DidYouMean.suggest('xyz', %w[map filter reduce])).to eq []
      end

      it 'returns empty on nil name' do
        expect(DidYouMean.suggest(nil, %w[helper])).to eq []
      end

      it 'returns empty on no candidates' do
        expect(DidYouMean.suggest('helpr', [])).to eq []
      end
    end
  end
end
