require 'jade/did_you_mean'

module Jade
  class Error
    attr_reader :entry, :span

    def initialize(entry:, span:, **rest)
      @entry = entry
      @span = span
    end

    def message
      fail NotImplementedError
    end

    def label
      nil
    end

    def notes
      []
    end

    def queried_name
      nil
    end

    def candidates
      []
    end

    def to_diagnostic(registry = nil, source: nil)
      source ||=
        case entry
        when String then registry&.get(entry)&.source
        else entry&.source
        end

      Jade::Diagnostics::Diagnostic.error(
        message,
        primary: Jade::Diagnostics::Label[source, span, label],
        annotations: notes + did_you_mean_notes,
      )
    end

    private

    def did_you_mean_notes
      return [] if queried_name.nil? || candidates.empty?

      Jade::DidYouMean
        .suggest(queried_name, candidates)
        .then { it.empty? ? [] : [help_annotation(it)] }
    end

    def help_annotation(suggestions)
      Jade::Diagnostics::Annotation[
        :help,
        "did you mean #{suggestions.map { "`#{it}`" }.join(' or ')}?",
      ]
    end

    def ordinal(n)
      if (11..13).cover?(n % 100)
        'th'
      else
        %w[th st nd rd th th th th th th][n % 10]
      end
        .then { "#{n}#{it}" }
    end
  end
end
