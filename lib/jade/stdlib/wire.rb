module Jade
  module Stdlib
    # Ruby readers and writers for the wire forms of stdlib types whose
    # Decodable / Encodable instances would otherwise walk a combinator
    # per value.
    #
    # These live here rather than in Decimal / Clock / Calendar because
    # those modules import Decode and Encode, so the instances cannot be
    # registered the other way round without a module cycle. The types
    # involved are compiled Jade, so every constant is resolved on first
    # use, not at load time.
    #
    # Readers return the decoded value, or nil when the text isn't well
    # formed. Both directions mirror what the Jade versions did, down to
    # `String.to_int` being `Integer(s, 10)` — permissive about
    # surrounding whitespace and underscores — and to the calendar
    # arithmetic being the stdlib's own, called rather than rewritten.
    module Wire
      extend self

      EPOCH_RATA_DIE = 719163
      DAY_MS = 86_400_000

      # --- readers ---

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
          days * DAY_MS +
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

      # --- writers ---

      # The inverse of `instant`, and of `Clock.to_iso`: seconds
      # precision, always UTC, no fractional part. `Calendar.to_iso_string`
      # left-pads without truncating, which is what `rjust` does — a
      # negative year still renders as "00-5".
      def instant_to_string(instant)
        ms = instant._1
        day_ms = ms % DAY_MS
        d = Jade::Calendar::Internal.from_rata_die(ms / DAY_MS + EPOCH_RATA_DIE)

        [
          pad(d.year, 4),
          '-', pad(Jade::Calendar::Internal.month_to_int(d.month), 2),
          '-', pad(d.day, 2),
          'T', pad(day_ms / 3_600_000, 2),
          ':', pad(day_ms % 3_600_000 / 60_000, 2),
          ':', pad(day_ms % 60_000 / 1_000, 2),
          'Z',
        ].join
      end

      private

      def int(s) = Integer(s, 10, exception: false)

      def pad(n, width) = n.to_s.rjust(width, '0')

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
