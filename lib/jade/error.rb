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

    def to_diagnostic(registry = nil)
      case entry
      when String then registry&.get(entry)&.source
      else entry&.source
      end.then do |source|
        Jade::Diagnostics::Diagnostic.error(
          message,
          primary: Jade::Diagnostics::Label[source, span, label],
          annotations: notes,
        )
      end
    end
  end
end
