require 'jade/source'
require 'jade/lexer'
require 'jade/ast'
require 'jade/parsing'
require 'jade/formatter'
require 'jade/frontend/comment_attacher'

module Jade
  module CLI
    module Fmt
      module_function

      def run(argv)
        mode = :stdout
        file = nil

        argv.each do |arg|
          case arg
          when '-i', '--in-place' then mode = :in_place
          when '-c', '--check'    then mode = :check
          when '-h', '--help'     then usage
          when /\A-/
            warn "unknown option: #{arg}"
            usage
          else
            usage if file
            file = arg
          end
        end

        format(file, mode)
      end

      def format(file, mode)
        source_text = read_source(file)
        source = Source.new(uri: file || 'stdin', text: source_text)

        case Parsing.parse(Lexer.tokenize(source), source:)
        in Ok([ast, comments])
          emit(Formatter.format(ast, comments:, source:) + "\n",
               source_text, file, mode)

        in Err(error)
          warn "Parse error: #{error.message}"
          exit 2
        end
      end

      def read_source(file)
        case
        when file then File.read(file)
        when !$stdin.tty? then $stdin.read
        else usage
        end
      end

      def emit(formatted, source_text, file, mode)
        case mode
        when :in_place
          usage unless file
          write_in_place(formatted, source_text, file)

        when :check
          exit 0 if formatted == source_text
          warn "#{file || 'stdin'}: not formatted"
          exit 1

        when :stdout
          print formatted
        end
      end

      def write_in_place(formatted, source_text, file)
        return if formatted == source_text

        File.write(file, formatted)
        warn "Formatted #{file}"
      end

      def usage
        warn <<~USAGE
          Usage: jade fmt [options] [file]

          Options:
            -i, --in-place   Rewrite the file in place.
            -c, --check      Exit 0 if formatted, 1 if drift, 2 on parse error.
                             Does not write.
            -h, --help       Show this message.

          Reads from stdin when no file is given.
        USAGE
        exit 1
      end
    end
  end
end
