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
    '+'  => :plus,
    '-'  => :minus,
    '*'  => :star,
    '/'  => :slash,
  }

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

    case remaining
    when /\A\s+/
      match = $&

      newlines = match.count("\n")
      if newlines > 0
        state.with(
          pos: state.pos + match.length,
          line: state.line + newlines,
          col: 1
        )
      else
        state.with(
          pos: state.pos + match.length,
          col: state.col + match.length
        )
      end
    when /\A(?:->|[():,+*\-\/])/
      match = $&
      type = SYMBOLS[match]
      add_token(state, type, match)

    when /\A[a-zA-Z_][a-zA-Z0-9_]*/
      match = $&
      type = KEYWORDS.include?(match) ? match.to_sym : :identifier
      add_token(state, type, match)

    when /\A\d+/
      match = $&
      add_token(state, :int, match.to_i, raw: match)

    else
      raise "Unexpected character at line #{state.line}, col #{state.col}: #{remaining[0]}"
    end
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
