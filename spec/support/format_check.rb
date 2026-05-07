require 'diff/lcs'
require 'diff/lcs/hunk'
require 'jade/lexer'
require 'jade/parsing'
require 'jade/ast'
require 'jade/formatter'
require 'jade/frontend/comment_attacher'

module Jade
  module FormatCheck
    extend self

    Mismatch = Class.new(StandardError)

    def run(text)
      source = Source.new(uri: '<format-check>', text:)
      Lexer.tokenize(source)
        .then { Parsing.parse(it, entry: source.uri) }
        .map { |(ast, comments)| Formatter.format(ast, comments:, source:) }
        .then do
          case it
          in Ok(result) then result + (text.end_with?("\n") ? "\n" : '')
          in Err(_) then nil
          end
        end
    rescue NoMatchingPatternError, NoMethodError
      nil
    end

    def assert!(text, label: nil)
      formatted = run(text)
      return if formatted.nil?
      return if formatted == text

      raise Mismatch, format_message(text, formatted, label)
    end

    private

    def format_message(input, output, label)
      header = label ? "Fixture isn't formatted (#{label})." : "Fixture isn't formatted."
      [
        red(header),
        '',
        unified_diff(input, output),
        '',
        "Fix all fixtures: #{bold('ruby script/reformat_fixtures.rb')}",
        "Skip this check:  #{bold('JADE_SKIP_FORMAT_CHECK=1 bundle exec rspec ...')}",
      ].join("\n")
    end

    def unified_diff(input, output)
      input_lines = input.lines.map(&:chomp)
      output_lines = output.lines.map(&:chomp)
      diffs = ::Diff::LCS.diff(input_lines, output_lines)
      return '  (no line-level diff; check trailing whitespace or line endings)' if diffs.empty?

      hunks = diffs.flat_map do |chunk|
        chunk.map do |change|
          if change.action == '+'
            green("  + #{change.element.empty? ? '⏎' : change.element}")
          else
            red("  - #{change.element.empty? ? '⏎' : change.element}")
          end
        end
      end

      header = [
        dim('  --- your fixture'),
        dim('  +++ what the formatter says it should be'),
      ]
      (header + hunks).join("\n")
    end

    def color?
      $stdout.tty? && ENV['NO_COLOR'].nil?
    end

    def red(s)   = color? ? "\e[31m#{s}\e[0m" : s
    def green(s) = color? ? "\e[32m#{s}\e[0m" : s
    def dim(s)   = color? ? "\e[2m#{s}\e[0m" : s
    def bold(s)  = color? ? "\e[1m#{s}\e[0m" : s
  end
end
