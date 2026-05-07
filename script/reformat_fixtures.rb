#!/usr/bin/env ruby
$LOAD_PATH.unshift(File.expand_path('../lib', __dir__))
$LOAD_PATH.unshift(File.expand_path('../spec', __dir__))

require 'jade'
require 'jade/ast'
require 'jade/parsing'
require 'jade/lexer'
require 'jade/formatter'
require 'jade/frontend/comment_attacher'
require 'support/format_check'

HEREDOC_RE = /(<<~['"]?JADE['"]?\b[^\n]*\n)(.*?)(^[ \t]*JADE\b)/m

def reindent(text, indent)
  text
    .lines
    .map { |line| line.strip.empty? ? line : indent + line }
    .join
end

def min_indent(text)
  text
    .lines
    .reject { |line| line.strip.empty? }
    .map { |line| line[/\A[ \t]*/].length }
    .min || 0
end

def strip_indent(text, n)
  text.lines.map { |line| line.length > n ? line[n..] : line.lstrip }.join
end

def reformat_file(path)
  src = File.read(path)
  any = false
  out = src.gsub(HEREDOC_RE) do |match|
    open_tag, body, close_tag = $1, $2, $3
    n = min_indent(body)
    raw = strip_indent(body, n)

    formatted = Jade::FormatCheck.run(raw)
    next match if formatted.nil? || formatted == raw

    indent = ' ' * n
    new_body = reindent(formatted, indent)
    new_body += "\n" unless new_body.end_with?("\n")
    any = true
    "#{open_tag}#{new_body}#{close_tag}"
  end

  return false unless any
  File.write(path, out)
  true
end

def reformat_jade_file(path)
  src = File.read(path)
  formatted = Jade::FormatCheck.run(src)
  return false if formatted.nil? || formatted == src

  File.write(path, formatted)
  true
end

paths = ARGV.empty? ? (Dir.glob('spec/**/*.rb') + Dir.glob('examples/**/*.jd')) : ARGV
changed = paths.select do |p|
  if p.end_with?('.jd')
    reformat_jade_file(p)
  else
    reformat_file(p)
  end
end
puts "Reformatted #{changed.size} file(s):"
changed.each { |p| puts "  #{p}" }
