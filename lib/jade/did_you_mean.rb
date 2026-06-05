require 'did_you_mean'

module Jade
  module DidYouMean
    extend self

    def suggest(name, candidates, max: 3)
      return [] if name.nil? || candidates.empty?

      ::DidYouMean::SpellChecker
        .new(dictionary: candidates.uniq)
        .correct(name)
        .first(max)
    end
  end
end
