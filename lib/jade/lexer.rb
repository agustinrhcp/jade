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

        when scanner.scan(/\A"/)
          (tokens << tok(:quote, scanner))
            .concat(tokenize_string(scanner))

        when scanner.scan(/"(?:\\.|[^"\\\n])*$/)
          tokens << tok(:malformed_string, scanner)

        else
          fail "FAILED TO SCAN at pos #{scanner.pos}, Next chars: #{scanner.rest[0,20].inspect}"
        end
      end

      tokens
    end

    private

    def tokenize_string(scanner)
      tokens = []
      chunk_start = scanner.pos

      until scanner.eos?
        case
        when scanner.scan(/\n/)
          tokens << string_chunk_tok(scanner, chunk_start)
          return tokens

        when scanner.scan(/\A"/)
          tokens << string_chunk_tok(scanner, chunk_start)
          tokens << tok(:quote, scanner)
          return tokens

        else
          scanner.getch
        end
      end

      tokens << string_chunk_tok(scanner, chunk_start)
      tokens
    end

    def tok(type, scanner)
      Token.new(type, scanner.matched, range(scanner))
    end

    def range(scanner) 
      (scanner.pos - scanner.matched_size)...scanner.pos
    end

    def string_chunk_tok(scanner, chunk_start)
      Token.new(
        :string_chunk,
        scanner.string[chunk_start...(scanner.pos - 1)],
        range(scanner)
      )
    end
  end
end
