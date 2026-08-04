module Jade
  module Stdlib
    module Decode
      # Ruby parsers for the wire forms of stdlib types whose Decodable
      # instance would otherwise walk a combinator per value.
      #
      # These live in Decode rather than in Decimal / Clock / Calendar
      # because those modules import Decode, so the instance cannot be
      # registered the other way round without a module cycle. The types
      # they build are compiled Jade, so every constant is resolved on
      # first use, not at load time.
      #
      # Each returns the decoded value, or nil when the text isn't well
      # formed. They mirror what the Jade versions accepted, down to
      # `String.to_int` being `Integer(s, 10)` — permissive about
      # surrounding whitespace and underscores — and to the date
      # arithmetic being the stdlib's own, called rather than rewritten.
      module Wire
        extend self

        EPOCH_RATA_DIE = 719163

        # "<coefficient>e<exponent>", exactly.
        def decimal(s)
          coefficient, exponent = s.split('e', 2)
          return nil unless exponent

          m = int(coefficient)
          e = int(exponent)

          m && e ? Jade::Decimal::Decimal[m, e] : nil
        end

        # "2026-06-17T12:00:00Z", "2026-06-17 12:00:00.250", and the other
        # shapes `Clock.from_iso` takes. No timezone offsets — the Jade
        # parser never accepted them either, so "+02:00" is still an error.
        def instant(s)
          date_part, time_part = split_dt(s)
          return nil unless date_part

          d = date(date_part)
          time = split_time(time_part)
          return nil unless d && time

          hour, minute, second, sub_ms = time
          days = Jade::Calendar::Internal.to_rata_die(d) - EPOCH_RATA_DIE

          Jade::Clock::Instant[
            days * 86_400_000 +
              hour * 3_600_000 + minute * 60_000 + second * 1_000 + sub_ms
          ]
        end

        # "2026-06-17", exactly three "-" separated numbers.
        def date(s)
          parts = s.split('-')
          return nil unless parts.length == 3

          year, month, day = parts.map { int(it) }
          return nil unless year && month && day

          # `month_from_int` answers Jan for anything outside 1..12 and
          # `from_calendar_date` never validated the day, so out-of-range
          # parts still produce a deterministic value rather than an error.
          # Calling it rather than restating it keeps that true, and keeps
          # the Month coming from whichever compiled Calendar is loaded —
          # caching instances here breaks as soon as a second compile
          # redefines the class.
          Jade::Calendar::Date[
            year,
            Jade::Calendar::Internal.month_from_int(month),
            day,
          ]
        end

        private

        def int(s) = Integer(s, 10, exception: false)

        # `T` first, then a space, and exactly two pieces either way.
        def split_dt(s)
          parts = s.split('T')
          parts = s.split(' ') unless parts.length == 2

          parts.length == 2 ? parts : nil
        end

        def split_time(s)
          parts = strip_z(s).split(':')
          return nil unless parts.length == 3

          hour = int(parts[0])
          minute = int(parts[1])
          second, sub_ms = seconds(parts[2])

          hour && minute && second && sub_ms ? [hour, minute, second, sub_ms] : nil
        end

        # Everything before the first "Z", but only when splitting on "Z"
        # leaves one or two pieces — matching what the Jade version did
        # with a stray second "Z".
        def strip_z(s)
          parts = s.split('Z')

          parts.length == 1 || parts.length == 2 ? parts[0] : s
        end

        def seconds(s)
          parts = s.split('.')

          case parts.length
          when 1 then [int(parts[0]), 0]
          when 2 then [int(parts[0]), millis(int(parts[1]), parts[1].length)]
          else [nil, nil]
          end
        end

        def millis(n, digits)
          return nil unless n

          case digits <=> 3
          when 0 then n
          when -1 then n * 10.pow(3 - digits)
          else n / 10.pow(digits - 3)
          end
        end
      end
    end
  end
end
