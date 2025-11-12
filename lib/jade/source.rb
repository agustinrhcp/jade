module Jade
  Source = Data.define(:uri, :text, :line_starts) do
    def self.load(uri)
      new(uri, File.read(uri))
    end

    def initialize(uri:, text:, line_starts: calculate_line_starts(text))
      super
    end

    private

    def calculate_line_starts(text)
      [0] + text.enum_for(:scan, /\n/).map { Regexp.last_match.end(0) }
    end
  end
end
