require 'jade'

module Jade
  module CLI
    SUBCOMMANDS = {
      'check' => 'Check',
      'fmt' => 'Fmt',
      'lsp' => 'Lsp',
      'q' => 'Q',
      'test' => 'Test',
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

          check  Type-check the project (or the given files).
          fmt    Format .jd source (stdin or file).
          lsp    Run the language server (stdio JSON-RPC).
          q      Headless query interface (hover/symbols/defn/refs/api).
          test   Run the project's `*_test.jd` modules.

        Run `jade COMMAND --help` for command-specific options.
      TXT
    end
  end
end
