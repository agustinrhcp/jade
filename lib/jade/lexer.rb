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

        when scanner.scan(/\A(True|False)\b/)
          tokens << tok(:bool, scanner)

        when scanner.scan(/\d+/)
          tokens << tok(:int, scanner)

        when scanner.scan(/\A"(?:\\.|[^"\\])*"/)
          tokens << tok(:string, scanner)

        else
          fail "FAILED TO SCAN at pos #{scanner.pos}, Next chars: #{scanner.rest[0,20].inspect}"
        end
      end

      tokens
    end

    private

    def tok(type, scanner)
      Token.new(type, scanner.matched, range(scanner))
    end

    def range(scanner) 
      (scanner.pos - scanner.matched_size)...scanner.pos
    end
  end
end
