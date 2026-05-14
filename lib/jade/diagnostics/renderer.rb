require 'jade/diagnostics'

module Jade::Diagnostics
  class Renderer
    SEVERITY_COLOR = {
      error: "\e[31m",
      warning: "\e[33m",
      note: "\e[36m",
      help: "\e[32m",
    }.freeze

    BLUE = "\e[34m".freeze
    BOLD = "\e[1m".freeze
    RESET = "\e[0m".freeze

    def initialize(colors: $stdout.tty?)
      @colors = colors
    end

    def render(diagnostic)
      [
        header(diagnostic),
        diagnostic.primary&.then { span_block(it, severity: diagnostic.severity) if it.source },
        *diagnostic
          .secondary
          .map { span_block(_1, severity: :secondary) },
        *diagnostic
          .annotations
          .map { annotation(_1) },
      ]
        .compact
        .join("\n")
    end

    def render_all(diagnostics)
      diagnostics
        .items
        .map { render(_1) }
        .join("\n\n")
    end

    private

    def header(diagnostic)
      "#{bold}#{color(diagnostic.severity)}#{diagnostic.severity}:#{reset} " \
        "#{bold}#{diagnostic.message}#{reset}"
    end

    def span_block(label, severity:)
      loc = location_of(label.source, label.span.begin)
      end_offset = label.span.exclude_end? ? [label.span.end - 1, 0].max : label.span.end
      end_loc = location_of(label.source, [end_offset, label.source.text.length - 1].min)
      multiline = end_loc.line > loc.line
      gutter_w = (multiline ? end_loc.line : loc.line).to_s.length
      blank = " " * gutter_w
      col_offset = loc.col - 1
      first_line = extract_line(label.source, loc.line).chomp
      span_len = [multiline ? first_line.length - col_offset : label.span.size, 1].max
      caret = severity == :secondary ? "-" : "^"
      underline = " " * col_offset + caret * span_len
      ann_text = label.message ? " #{label.message}" : ""
      uc = severity == :secondary ? blue : color(severity)

      lines = [
        "#{blank}#{blue} --> #{reset}#{label.source.uri}:#{loc.line}:#{loc.col}",
        "#{blank}#{blue} |#{reset}",
        "#{blue}#{loc.line.to_s.rjust(gutter_w)} | #{reset}#{first_line}",
        "#{blank}#{blue} | #{reset}#{bold}#{uc}#{underline}#{reset}",
      ]

      if multiline
        (loc.line + 1..end_loc.line).each do |n|
          source_line = extract_line(label.source, n).chomp
          lines << "#{blue}#{n.to_s.rjust(gutter_w)} | #{reset}#{source_line}"
          next unless n == end_loc.line

          last_underline = caret * [[end_loc.col, 1].max, source_line.length].min
          lines << "#{blank}#{blue} | #{reset}#{bold}#{uc}#{last_underline}#{ann_text}#{reset}"
        end
      else
        lines[-1] = "#{blank}#{blue} | #{reset}#{bold}#{uc}#{underline}#{ann_text}#{reset}"
      end

      lines << "#{blank}#{blue} |#{reset}"
      lines.join("\n")
    end

    def annotation(ann)
      "  #{bold}#{color(ann.kind)}= #{ann.kind}:#{reset} #{ann.message}"
    end

    Location = Data.define(:line, :col)

    def location_of(source, offset)
      (source.line_starts.rindex { _1 <= offset } || 0)
        .then { Location[it + 1, offset - source.line_starts[it] + 1] }
    end

    def extract_line(source, line_number)
      s = source.line_starts[line_number - 1]
      e = source.line_starts[line_number] || source.text.length
      source.text[s...e]
    end

    def color(severity)
      @colors ? SEVERITY_COLOR.fetch(severity, "") : ""
    end

    def blue
      @colors ? BLUE : ""
    end

    def bold
      @colors ? BOLD : ""
    end

    def reset
      @colors ? RESET : ""
    end
  end
end
