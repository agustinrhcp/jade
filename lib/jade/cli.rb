require 'jade'

module Jade
  module CLI
    SUBCOMMANDS = {
      'api' => 'Api',
      'check' => 'Check',
      'eject' => 'Eject',
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
    rescue Project::NotFound, RuntimeError => e
      warn "jade: #{e.message}"
      exit 1
    end

    def usage(io = $stdout)
      io.puts <<~TXT
        Usage: jade COMMAND [ARGS]

          api    Print the public surface as JSON, or check it has not moved.
          check  Type-check the project (or the given files).
          eject  Write the project as Ruby that runs without the gem.
          fmt    Format .jd source (stdin or file).
          lsp    Run the language server (stdio JSON-RPC).
          q      Headless query interface (hover/symbols/defn/refs/api).

        Run `jade COMMAND --help` for command-specific options.
      TXT
    end
  end
end
