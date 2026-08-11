module Jade
  module Stdlib
    # Text representations of stdlib types, read in Ruby. Lives here rather
    # than in Decimal / Clock / Calendar: those import Decode, so the
    # instance cannot be registered the other way round. The types are
    # compiled Jade, so constants resolve on first use.
    #
    # Accepts exactly what the Jade parsers did, down to `String.to_int`
    # being `Integer(s, 10)` — whitespace and underscores included.
    module Text
      extend self

      EPOCH_RATA_DIE = 719163

      def to_decimal(s)
        coefficient, exponent = s.split('e', 2)
        return nil unless exponent

        m = int(coefficient)
        e = int(exponent)

        m && e ? Jade::Decimal::Decimal[m, e] : nil
      end

      # No timezone offsets: `Clock.from_iso` never took them either.
      def to_instant(s)
        date_part, time_part = split_dt(s)
        return nil unless date_part

        d = to_date(date_part)
        time = split_time(time_part)
        return nil unless d && time

        hour, minute, second, sub_ms = time
        days = Jade::Calendar::Internal.to_rata_die(d) - EPOCH_RATA_DIE

        Jade::Clock::Instant[
          days * 86_400_000 +
            hour * 3_600_000 + minute * 60_000 + second * 1_000 + sub_ms
        ]
      end

      def to_date(s)
        parts = s.split('-')
        return nil unless parts.length == 3

        year, month, day = parts.map { int(it) }
        return nil unless year && month && day

        # Answers Jan outside 1..12 and never validates the day — calling
        # it keeps that. Don't cache the Months: a second compile
        # redefines the class.
        Jade::Calendar::Date[
          year,
          Jade::Calendar::Internal.month_from_int(month),
          day,
        ]
      end

      private

      def int(s) = Integer(s, 10, exception: false)

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

      # A stray second "Z" falls through unstripped, as it did before.
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
