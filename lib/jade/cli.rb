require 'jade'

module Jade
  module CLI
    SUBCOMMANDS = {
      'fmt' => 'Fmt',
      'lsp' => 'Lsp',
      'q' => 'Q',
    }.freeze

    module_function

    def run(argv)
      sub, *rest = argv

      case sub
      when nil, '-h', '--help', 'help'
        usage

      when *SUBCOMMANDS.keys
        require "jade/cli/#{sub}"
        const_get(SUBCOMMANDS.fetch(sub)).run(rest)

      else
        warn "jade: unknown command #{sub.inspect}\n\n"
        usage($stderr)
        exit 1
      end
    end

    def usage(io = $stdout)
      io.puts <<~TXT
        Usage: jade COMMAND [ARGS]

          fmt    Format .jd source (stdin or file).
          lsp    Run the language server (stdio JSON-RPC).
          q      Headless query interface (hover/symbols/defn/refs).

        Run `jade COMMAND --help` for command-specific options.
      TXT
    end
  end
end
