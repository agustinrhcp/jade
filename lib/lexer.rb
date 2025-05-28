require 'set'

require 'token'

module Lexer
  extend self

  State = Data.define(:code, :pos, :line, :col, :tokens)

  KEYWORDS = Set['def', 'end']
  SYMBOLS = {
    '->' => :arrow,
    '('  => :lparen,
    ')'  => :rparen,
    ':'  => :colon,
    ','  => :comma,

    # arithmetic
    '+'  => :plus,
    '-'  => :minus,
    '*'  => :star,
    '/'  => :slash,

    # comparison
    '==' => :eq,
    '!=' => :not_eq,
    '<'  => :lt,
    '<=' => :lte,
    '>'  => :gt,
    '>=' => :gte,
  }
  SYMBOLS_REGEX = Regexp.union(SYMBOLS.keys.sort_by { |k| -k.length })

  def scan(code)
    state = State.new(code, 0, 1, 1, [])

    loop do
      state = next_token(state)
      break if eof?(state)
    end

    state.tokens
  end

  def next_token(state)
    remaining = state.code[state.pos..]

    return state if remaining.nil? || remaining.empty?

    if (match = /\A\s+/.match(remaining))
      whitespace = match[0]
      newlines = whitespace.count("\n")
      if newlines > 0
        return state.with(
          pos: state.pos + whitespace.length,
          line: state.line + newlines,
          col: 1
        )
      else
        return state.with(
          pos: state.pos + whitespace.length,
          col: state.col + whitespace.length
        )
      end
    end

    # Symbols (operators, punctuation)
    if (match = /\A#{SYMBOLS_REGEX}/.match(remaining))
      sym = match[0]
      type = SYMBOLS.fetch(sym)
      return add_token(state, type, sym)
    end

    # Booleans
    if (match = /\A(True|False)\b/.match(remaining))
      val = match[1] == "True"
      return add_token(state, :bool, val, raw: match[0])
    end

    # String literals (double quotes, supports escaped quotes)
    if (match = /\A"(?:\\.|[^"\\])*"/.match(remaining))
      # Strip quotes and unescape basic escapes (\" and \\)
      raw_str = match[0]
      str_val = raw_str[1..-2].gsub(/\\"/, '"').gsub(/\\\\/, '\\')
      return add_token(state, :string, str_val, raw: raw_str)
    end

    # Identifiers and keywords
    if (match = /\A[a-zA-Z_][a-zA-Z0-9_]*/.match(remaining))
      word = match[0]
      type = KEYWORDS.include?(word) ? word.to_sym : :identifier
      return add_token(state, type, word)
    end

    # Integers (decimal only)
    if (match = /\A\d+/.match(remaining))
      val = match[0].to_i
      return add_token(state, :int, val, raw: match[0])
    end

    raise "Unexpected character at line #{state.line}, col #{state.col}: #{remaining[0]}"
  end

  def add_token(state, type, value, raw: nil)
    raw ||= value.to_s
    token = Token.new(type, value, Position.new(state.line, state.col))
    state.with(
      pos: state.pos + raw.length,
      col: state.col + raw.length,
      tokens: state.tokens + [token]
    )
  end

  def eof?(state)
    state.pos >= state.code.length
  end
end
