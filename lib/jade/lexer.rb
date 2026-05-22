require 'strscan'
require 'set'

require 'jade/source'

module Jade
  Token = Data.define(:type, :value, :range)

  module Lexer
    extend self

    KEYWORDS = Set[
      'def',
      'type',
      'module',
      'import',
      'exposing',
      'if',
      'then',
      'else',
      'case',
      'of',
      'as',
      'uses',
      'with',
      'struct',
      'interface',
      'implements',
      'extends',
    ].freeze

    SYMBOLS = {
      '->' => :arrow,
      '('  => :lparen,
      ')'  => :rparen,
      ':'  => :colon,
      ','  => :comma,
      '{'  => :lbrace,
      '}'  => :rbrace,
      '['  => :lbrack,
      ']'  => :rbrack,
      '..' => :dotdot,
      '.'  => :dot,
      '@'  => :at,

      # arithmetic
      '+'  => :plus,
      '-'  => :minus,
      '*'  => :star,
      '/'  => :slash,
      '|'  => :pipe,

      # comparison
      '==' => :eq,
      '!=' => :not_eq,
      '<'  => :lt,
      '<=' => :lte,
      '>'  => :gt,
      '>=' => :gte,

      '++' => :plusplus,
      '='  => :assign,

      '|>' => :pipe_forward,
      '<|' => :pipe_backward,
      '<-' => :bind,

      '_' => :wildcard, # also used as placeholder
      '::' => :coloncolon,

      '&&' => :andand,
      '||' => :oror,
    }.freeze

    SYMBOLS_REGEX = Regexp.union(SYMBOLS.keys.sort_by { |k| -k.length })

    INVALID_OPS = %w[/=].freeze
    INVALID_OP_REGEX = Regexp.union(INVALID_OPS.sort_by { |k| -k.length })

    def tokenize(source)
      source => Source(text:)

      scanner = StringScanner.new(text)
      tokens = []

      until scanner.eos?
        case
        when scanner.scan(/\s+/)

        when scanner.scan(INVALID_OP_REGEX)
          tokens << tok(:invalid_op, scanner)

        when scanner.scan(/\A#[^\n]*/)
          tokens << tok(:comment, scanner)

        when scanner.scan(/\A[a-z][a-z0-9_]*\??|\A_[a-z0-9_]+\??/)
          type = KEYWORDS.include?(scanner.matched) ? scanner.matched.to_sym : :identifier
          tokens << tok(type, scanner)

        when scanner.scan(SYMBOLS_REGEX)
          type = SYMBOLS.fetch(scanner.matched)
          tokens << tok(type, scanner)

        when scanner.scan(/\A(True|False)\b/)
          tokens << tok(:bool, scanner)

        when scanner.scan(/\A[A-Z][A-Za-z0-9_]*/)
          tokens << tok(:constant, scanner)

        when scanner.scan(/\d+\.\d+/)
          tokens << tok(:float, scanner)

        when scanner.scan(/\d+/)
          tokens << tok(:int, scanner)

        when scanner.scan(/\A"/)
          (tokens << tok(:quote, scanner))
            .concat(tokenize_string(scanner))

        when scanner.scan(/\A'.'/)
          tokens << Token.new(:char, scanner.matched[1], range(scanner))

        when scanner.scan(/\A'[^']*'/)
          fail "Invalid char literal #{scanner.matched.inspect}: must be a single character"

        else
          fail "FAILED TO SCAN at pos #{scanner.pos}, Next chars: #{scanner.rest[0, 20].inspect}"
        end
      end

      tokens
    end

    private

    def tokenize_string(scanner)
      tokens = []
      value = +''
      chunk_start = scanner.pos

      until scanner.eos?
        case
        when scanner.scan(/\n/)
          tokens << Token.new(:string_chunk, value, chunk_start...(scanner.pos - 1))
          return tokens

        when scanner.scan(/\A"/)
          tokens << Token.new(:string_chunk, value, chunk_start...(scanner.pos - 1))
          tokens << tok(:quote, scanner)
          return tokens

        when scanner.scan(/\A\\n/)  then value << "\n"
        when scanner.scan(/\A\\t/)  then value << "\t"
        when scanner.scan(/\A\\r/)  then value << "\r"
        when scanner.scan(/\A\\"/)  then value << '"'
        when scanner.scan(/\A\\\\/) then value << '\\'

        else
          value << scanner.getch
        end
      end

      tokens << Token.new(:string_chunk, value, chunk_start...scanner.pos)
      tokens
    end

    def tok(type, scanner)
      Token.new(type, scanner.matched, range(scanner))
    end

    def range(scanner) 
      (scanner.pos - scanner.matched_size)...scanner.pos
    end

    def string_chunk_tok(scanner, chunk_start)
      range = chunk_start...(scanner.pos - 1)

      Token.new(
        :string_chunk,
        scanner.string[range],
        range,
      )
    end
  end
end
