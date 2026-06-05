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
        data: suggestion_data,
      )
    end

    private

    def suggestions
      @_suggestions ||= queried_name && Jade::DidYouMean.suggest(queried_name, candidates)
    end

    def did_you_mean_notes
      return [] if suggestions.nil? || suggestions.empty?

      [help_annotation(suggestions)]
    end

    def suggestion_data
      return nil if suggestions.nil? || suggestions.empty?

      { suggestions: }
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
