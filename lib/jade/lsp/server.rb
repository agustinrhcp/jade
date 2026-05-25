require 'json'

module Jade
  module LSP
    class Server
      def initialize(input: $stdin, output: $stdout)
        @input = input
        @output = output
        @input.binmode
        @output.binmode
        @output.sync = true
      end

      def run
        state = State.empty
        loop do
          message = read_message
          break unless message

          state, outbound = safe_dispatch(state, message)
          outbound.each { write_message(it) }
          break if message['method'] == 'exit'
        end
      end

      private

      def safe_dispatch(state, message)
        Handlers.dispatch(state, message)
      rescue StandardError => e
        $stderr.puts "[jade-lsp] handler crash: #{e.class}: #{e.message}"
        $stderr.puts e.backtrace.first(20).join("\n")
        [state, []]
      end

      def read_message
        headers = read_headers or return nil
        length = headers['Content-Length'].to_i
        JSON.parse(@input.read(length))
      rescue JSON::ParserError => e
        $stderr.puts "[jade-lsp] bad json: #{e.message}"
        nil
      end

      def read_headers
        headers = {}
        while (line = @input.gets("\r\n"))
          stripped = line.chomp("\r\n")
          return headers if stripped.empty?

          k, _, v = stripped.partition(': ')
          headers[k] = v
        end
        nil
      end

      def write_message(message)
        body = JSON.generate(message)
        @output.write("Content-Length: #{body.bytesize}\r\n\r\n#{body}")
      end
    end
  end
end
