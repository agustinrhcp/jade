require 'fileutils'

require 'jade'
require 'jade/repl'

module Jade
  module CLI
    # A prompt that compiles each input as a module of its own, importing
    # what earlier inputs defined, so it accepts exactly what a module would.
    module Repl
      module_function

      SPACE = 'jade_repl'.freeze
      PROMPT = 'jade> '.freeze
      MORE = '  ... '.freeze
      COMMANDS = %w[:t :type :reset :help :quit].freeze
      HISTORY_SIZE = 500
      NEWLINE = "\u2424".freeze

      Quit = Data.define

      HELP = <<~TXT.chomp
        expr           evaluate it and show its value and type
        name = expr    bind a value for later inputs
        def, type, struct, interface, implements, uses, import
                       as in a module; a later input shadows an earlier one
        :t expr        the type of expr, without evaluating it
        :reset         forget everything
        :q             leave
      TXT

      def run(argv)
        usage if argv.any? { it == '-h' || it == '--help' }

        required(argv).each { require File.expand_path(it) }
        project = Project.find

        ::Jade::Repl::Host
          .create(source_root: source_root(project), space: SPACE)
          .then { |host| $stdin.tty? ? interactive(host, project) : piped(host) }
      end

      def piped(host)
        output = ::Jade::Repl::Output[colors: false]
        session = ::Jade::Repl::Session.start(host)
        ok = true

        inputs($stdin.each_line).each do |text|
          outcome = step(session, text)
          break if outcome.is_a?(Quit)

          emit(output.render(outcome))
          session = advance(session, outcome)
          ok &&= outcome.is_a?(::Jade::Repl::Accepted)
        end

        exit 1 unless ok
      ensure
        host.clean
      end

      def interactive(host, project)
        require 'reline'

        output = ::Jade::Repl::Output[colors: $stdout.tty?]
        state = { session: ::Jade::Repl::Session.start(host) }
        history = history_path(project)

        load_history(history)
        configure(state)
        puts "Jade #{VERSION}. :help for commands, Ctrl-D to leave."

        loop do
          text = Reline.readmultiline(PROMPT, true) { submittable?(it) }
          break unless text

          outcome = step(state[:session], text)
          break if outcome.is_a?(Quit)

          emit(output.render(outcome))
          state[:session] = advance(state[:session], outcome)
        rescue Interrupt
          puts
        end
      ensure
        save_history(history) if history
        host.clean
      end

      def step(session, text)
        case text.strip
        when ':q', ':quit' then Quit.new
        when ':h', ':help' then ::Jade::Repl::Accepted[session, [::Jade::Repl::Line[HELP, nil]]]
        when ':reset' then ::Jade::Repl::Accepted[reset(session), []]
        when /\A:t(?:ype)?\s+(.+)\z/m then session.type_of(Regexp.last_match(1))
        when /\A:/ then unknown(text.strip)
        else session.submit(text)
        end
      end

      def reset(session)
        session
          .host
          .with(space: next_space(session.host.space))
          .then { ::Jade::Repl::Session.start(it) }
      end

      def next_space(space)
        space[/\d+\z/].to_i.then { "#{SPACE}#{[it, 1].max + 1}" }
      end

      def unknown(command)
        Diagnostics::List
          .empty
          .add(Diagnostics::Diagnostic.error("Unknown command #{command}; :help lists them", primary: nil))
          .then { ::Jade::Repl::Rejected[it] }
      end

      def advance(session, outcome)
        outcome.is_a?(::Jade::Repl::Accepted) ? outcome.session : session
      end

      def emit(text)
        puts text unless text.empty?
      end

      # Piped text is split the way the prompt splits it: an input ends when
      # it parses, or at a blank line.
      def inputs(lines)
        Enumerator.new do |yielder|
          lines
            .reduce('') do |buffer, line|
              (buffer + line).then do |text|
                next '' if text.strip.empty?
                next text unless line.strip.empty? || submittable?(text.chomp)

                yielder << text
                ''
              end
            end
            .then { yielder << it unless it.strip.empty? }
        end
      end

      def submittable?(buffer)
        text = buffer.chomp

        text.split("\n", -1).last.to_s.strip.empty? ||
          text.lstrip.start_with?(':') ||
          ::Jade::Repl::Input.complete?(text)
      end

      def configure(state)
        Reline.prompt_proc = ->(lines) { lines.each_index.map { it.zero? ? PROMPT : MORE } }
        Reline.completion_proc = ->(word) { candidates(state[:session], word) }
      end

      def candidates(session, word)
        (session.names + COMMANDS).select { it.start_with?(word) }
      end

      # A module may not live where the REPL keeps its inputs: a cell and a
      # file would claim the same module name.
      def source_root(project)
        return nil unless project

        project.source_root.tap do |root|
          Dir.glob(File.join(root, "#{SPACE}*")).first&.then do
            fail "#{it} is in the way: the REPL compiles its inputs as modules there"
          end
        end
      end

      def history_path(project)
        project&.then { File.join(it.root, '.jade', 'repl_history') } ||
          ENV
            .fetch('XDG_STATE_HOME') { File.expand_path('~/.local/state') }
            .then { File.join(it, 'jade', 'repl_history') }
      end

      def load_history(path)
        return unless File.exist?(path)

        File
          .readlines(path, chomp: true)
          .last(HISTORY_SIZE)
          .each { Reline::HISTORY << it.gsub(NEWLINE, "\n") }
      end

      def save_history(path)
        FileUtils.mkdir_p(File.dirname(path))

        Reline::HISTORY
          .to_a
          .last(HISTORY_SIZE)
          .map { it.gsub("\n", NEWLINE) }
          .then { File.write(path, it.join("\n") + "\n") }
      end

      def required(argv)
        argv
          .each_cons(2)
          .select { |flag, _| flag == '--require' }
          .map(&:last)
      end

      def usage
        warn <<~USAGE
          Usage: jade repl [--require FILE]...

          Reads Jade at a prompt and shows each value with its type. Inside a
          project, its modules can be imported. Piped input is read to the end,
          one result per input, and exits 1 if any input failed.

            --require FILE   Load a Ruby file first, such as the app your ports need.
        USAGE
        exit 1
      end
    end
  end
end
