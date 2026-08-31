require 'jade/testing/results'

module Jade
  module Testing
    class Reporter
      MARKS = { Passed => '.', Failed => 'x', Crashed => '!', Broken => '!' }.freeze
      COLORS = { Passed => 32, Failed => 31, Crashed => 33, Broken => 33 }.freeze
      LIB = File.expand_path('../..', __dir__).freeze

      # `:doc` names every test instead, which stops scaling with the suite.
      DOTS_PER_LINE = 60

      def initialize(io: $stdout, color: io.tty?, format: :dots)
        @io = io
        @color = color
        @format = format
      end

      def report(results, broken, timing)
        progress(results)
        io.puts
        broken.each { render_broken(it) }
        failures(results).each { render_failure(it) }
        io.puts summary(results, broken, timing)
      end

      private

      attr_reader :io, :color, :format

      def progress(results)
        format == :doc ? tree(results) : dots(results)
      end

      def dots(results)
        results
          .each_slice(DOTS_PER_LINE)
          .each { |slice| io.puts slice.map { |result| mark(result) }.join }
      end

      def tree(results)
        results.reduce([]) do |shown, result|
          groups = result.path[0..-2]

          headers(shown, groups)
          io.puts "#{pad(groups.size)}#{mark(result)} #{result.path.last}"

          groups
        end
      end

      def headers(shown, groups)
        (0...groups.size)
          .find { shown[it] != groups[it] }
          .then { it || groups.size }
          .then { (it...groups.size).each { |i| io.puts "#{pad(i)}#{groups[i]}" } }
      end

      def render_failure(result)
        io.puts "#{mark(result)} #{result.path.join(' > ')}"
        io.puts

        case result
        in Failed(reasons:)
          reasons.each { render_reason(it) }

        in Crashed(error:)
          io.puts "    #{error.class}: #{error.message}"
          io.puts(*frames(error).map { "      #{it}" })
          io.puts
        end
      end

      def frames(error)
        error
          .backtrace
          .reject { it.start_with?(LIB) }
          .take(3)
      end

      def render_reason(reason)
        io.puts "    expected #{reason.description}"
        io.puts
        io.puts "      actual:   #{reason.actual}"
        io.puts "      expected: #{reason.expected}"
        io.puts
      end

      def render_broken(broken)
        io.puts "#{mark(broken)} #{broken.module_name}"
        io.puts
        io.puts "    #{broken.error.message}"
        io.puts
      end

      def summary(results, broken, timing)
        counts(results, broken)
          .then { it.join(', ') }
          .then { "#{it} (#{took(timing)})" }
          .then { paint(it, worst(results, broken)) }
      end

      def took(timing)
        "compiled in #{seconds(timing.compile)}, ran in #{seconds(timing.run)}"
      end

      # "0.00s" reads like a broken clock rather than like the point.
      def seconds(value)
        value < 1 ? "%dms" % (value * 1000).round : "%.2fs" % value
      end

      def counts(results, broken)
        errors = results.count { Crashed === it } + broken.size

        [
          count(results.size, 'test'),
          count(results.count { Failed === it }, 'failure'),
          (count(errors, 'error') unless errors.zero?),
        ].compact
      end

      def count(n, word)
        "#{n} #{word}#{'s' unless n == 1}"
      end

      def worst(results, broken)
        return COLORS[Crashed] if broken.any? || results.any? { Crashed === it }
        return COLORS[Failed] if results.any? { Failed === it }

        COLORS[Passed]
      end

      def failures(results)
        results.reject { Passed === it }
      end

      def mark(result)
        paint(MARKS.fetch(result.class), COLORS.fetch(result.class))
      end

      def pad(depth)
        '  ' * depth
      end

      def paint(text, code)
        color ? "\e[#{code}m#{text}\e[0m" : text
      end
    end
  end
end
