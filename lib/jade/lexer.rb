require 'strscan'

require 'jade/source'

module Jade
  Token = Data.define(:type, :value, :range)

  module Lexer
    extend self

    def tokenize(source)
      source => Source(text:)

      scanner = StringScanner.new(text)
      tokens = []

      until scanner.eos?
        case
        when scanner.scan(/\s+/)
        when scanner.scan(/\d+/)
          tokens << Token.new(
            :int,
            scanner.matched,
            (scanner.pos - scanner.matched_size)...scanner.pos,
          )
        end
      end

      tokens
    end
  end
end
