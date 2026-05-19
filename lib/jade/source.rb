module Jade
  Source = Data.define(:uri, :text, :line_starts) do
    def self.load(source_root, uri, overlays: {})
      text = overlays[uri] || File.read(File.join(source_root, uri))
      new(uri, text)
    end

    def self.load_from_module_name(source_root, name, overlays: {})
      name.split('.')
        .compact
        .map { snake_case(it) }
        .then { |(*rest, last)| rest + [last + '.jd'] }
        .then { File.join(*it) }
        .then { load(source_root, it, overlays:) }
    end

    def initialize(uri:, text:, line_starts: calculate_line_starts(text))
      super
    end

    def to_module_name
      uri
        .delete_suffix('.jd')
        .split('/')
        .map { Source.camelize(it) }
        .join('.')
    end

    private

    def calculate_line_starts(text)
      [0] + text.enum_for(:scan, /\n/).map { Regexp.last_match.end(0) }
    end

    def self.camelize(str)
      str.split('_').map { |part| part.capitalize }.join
    end

    def self.snake_case(str)
      str
        .gsub(/([A-Z]+)([A-Z][a-z])/, '\1_\2')  # ABCXyz -> ABC_Xyz
        .gsub(/([a-z\d])([A-Z])/, '\1_\2')      # abcXyz -> abc_Xyz
        .downcase
    end
  end
end
