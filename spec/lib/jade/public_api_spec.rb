require 'spec_helper'

module Jade
  # A user's code depends on these names and shapes. Changing one is
  # allowed; changing one without noticing is not, which is what this
  # stops: the diff lands in the same commit as the changelog entry that
  # says what to write instead.
  describe 'the public API' do
    before { PublicApi.write! if ENV['UPDATE_API_SNAPSHOT'] }

    it 'is what the snapshot says' do
      expect(PublicApi.snapshot).to eq(PublicApi.committed), <<~MSG
        The public API moved.

        If that was deliberate, record it in CHANGELOG.md (docs/stability.md
        says what counts as a break) and update the snapshot in the same
        commit:

          UPDATE_API_SNAPSHOT=1 bundle exec rspec spec/lib/jade/public_api_spec.rb

        #{PublicApi.diff}
      MSG
    end
  end
end
