require 'uri'

module Jade
  module LSP
    module Converters
      extend self

      # Byte offsets, not UTF-16 code units. Matches the `utf-8` position
      # encoding negotiated at initialize; under the default `utf-16`,
      # columns drift right by N for each multi-byte char on the line.
      def offset_to_position(source, offset)
        line = source.line_starts.rindex { it <= offset } || 0
        { line:, character: offset - source.line_starts[line] }
      end

      def span_to_range(source, span)
        {
          start: offset_to_position(source, span.begin),
          end:   offset_to_position(source, span.end),
        }
      end

      SEVERITY = { error: 1, warning: 2, info: 3, hint: 4 }.freeze

      def diagnostic_to_lsp(diagnostic)
        {
          range: diagnostic.primary.then { span_to_range(it.source, it.span) },
          severity: SEVERITY.fetch(diagnostic.severity, 3),
          source: 'jade',
          message: diagnostic_message(diagnostic),
        }
      end

      def relative_path(uri, source_root)
        uri
          .sub(%r{\Afile://}, '')
          .then { URI::DEFAULT_PARSER.unescape(it) }
          .then { Pathname.new(it).relative_path_from(Pathname.new(source_root)).to_s }
      end

      def lsp_uri(relative_path, source_root)
        File
          .expand_path(File.join(source_root, relative_path))
          .then { URI::DEFAULT_PARSER.escape(it) }
          .then { "file://#{it}" }
      end

      private

      def diagnostic_message(diagnostic)
        [diagnostic.message, *diagnostic.annotations.map { "#{it.kind}: #{it.message}" }]
          .join("\n")
      end
    end
  end
end
