require 'jade/stdlib/compiled'

module Jade
  module Stdlib
    module Clock
      extend self
      extend Compiled

      def uri
        'clock.jd'
      end

      def imports
        [Basics, Maybe, Result, Task, String, Tuple, Calendar]
      end

      def default_imports
        []
      end

      def code
        <<~JADE
          module Clock exposing(Instant, Duration,
                                now, epoch,
                                millis,    in_millis,
                                seconds,   in_seconds,
                                minutes,   in_minutes,
                                hours,     in_hours,
                                days,      in_days,
                                parts,
                                add, diff,
                                from_iso, to_iso,
                                on_date, at_time)

          type Instant  = Instant(Int)
          type Duration = Duration(Int)

          uses Jade::Clock::Runtime with
            now_raw: Task({ millis: Int }, Never)
          end

          def now() -> Task(Instant, Never)
            raw <- now_raw()
            Task.succeed(Instant(raw.millis))
          end

          def epoch() -> Instant
            Instant(0)
          end

          def millis(n: Int) -> Duration
            Duration(n)
          end

          def in_millis(d: Duration) -> Int
            Duration(n) = d
            n
          end

          def seconds(n: Int) -> Duration
            Duration(n * 1000)
          end

          def in_seconds(d: Duration) -> Int
            in_millis(d) / 1000
          end

          def minutes(n: Int) -> Duration
            Duration(n * 60000)
          end

          def in_minutes(d: Duration) -> Int
            in_millis(d) / 60000
          end

          def hours(n: Int) -> Duration
            Duration(n * 3600000)
          end

          def in_hours(d: Duration) -> Int
            in_millis(d) / 3600000
          end

          def days(n: Int) -> Duration
            Duration(n * 86400000)
          end

          def in_days(d: Duration) -> Int
            in_millis(d) / 86400000
          end

          def parts(d: Duration) -> { days: Int, hours: Int, minutes: Int, seconds: Int, millis: Int }
            ms = in_millis(d)
            { days:    ms / 86400000,
              hours:   mod(ms, 86400000) / 3600000,
              minutes: mod(ms, 3600000) / 60000,
              seconds: mod(ms, 60000) / 1000,
              millis:  mod(ms, 1000) }
          end

          def add(i: Instant, d: Duration) -> Instant
            Instant(ms) = i
            Instant(ms + in_millis(d))
          end

          def diff(a: Instant, b: Instant) -> Duration
            Instant(ams) = a
            Instant(bms) = b
            Duration(bms - ams)
          end

          def on_date(i: Instant) -> Calendar.Date
            Instant(ms) = i
            Calendar.from_rata_die(floor_div(ms, 86400000) + 719163)
          end

          def at_time(i: Instant) -> { hour: Int, minute: Int, second: Int, millisecond: Int }
            Instant(ms) = i
            day_ms = mod(ms, 86400000)
            { hour:        day_ms / 3600000,
              minute:      mod(day_ms, 3600000) / 60000,
              second:      mod(day_ms, 60000) / 1000,
              millisecond: mod(day_ms, 1000) }
          end

          def floor_div(a: Int, b: Int) -> Int
            q = a / b
            if a < 0 && mod(a, b) != 0 then q - 1 else q end
          end

          def to_iso(i: Instant) -> String
            d = on_date(i)
            tod = at_time(i)
            Calendar.to_iso_string(d) ++ "T"
              ++ pad2(tod.hour) ++ ":" ++ pad2(tod.minute) ++ ":" ++ pad2(tod.second) ++ "Z"
          end

          def pad2(n: Int) -> String
            s = String.from_int(n)
            if String.length(s) < 2 then "0" ++ s else s end
          end

          def from_iso(s: String) -> Result(Instant, String)
            case split_dt(s)
            of Just((date_part, time_part)) then
              case (Calendar.from_iso_string(date_part), parse_time(time_part))
              of (Ok(d), Ok((h, m, sec, sub))) then
                Ok(combine(d, h, m, sec, sub))
              of _ then Err("invalid timestamp: " ++ s)
              end
            of Nothing then Err("invalid timestamp: " ++ s)
            end
          end

          def split_dt(s: String) -> Maybe((String, String))
            case String.split(s, "T")
            of [d, t] then Just((d, t))
            of _ then
              case String.split(s, " ")
              of [d, t] then Just((d, t))
              of _ then Nothing
              end
            end
          end

          def parse_time(s: String) -> Result((Int, Int, Int, Int), String)
            case String.split(strip_z(s), ":")
            of [h, m, sec_part] then
              case (String.to_int(h), String.to_int(m), parse_seconds(sec_part))
              of (Just(hi), Just(mi), Just((si, ms))) then Ok((hi, mi, si, ms))
              of _ then Err("bad time: " ++ s)
              end
            of _ then Err("bad time: " ++ s)
            end
          end

          def strip_z(s: String) -> String
            case String.split(s, "Z")
            of [head, _] then head
            of [head]    then head
            of _ then s
            end
          end

          def parse_seconds(s: String) -> Maybe((Int, Int))
            case String.split(s, ".")
            of [secs] then
              case String.to_int(secs)
              of Just(si) then Just((si, 0))
              of Nothing  then Nothing
              end
            of [secs, frac] then
              case (String.to_int(secs), String.to_int(frac))
              of (Just(si), Just(fi)) then Just((si, frac_to_millis(fi, String.length(frac))))
              of _ then Nothing
              end
            of _ then Nothing
            end
          end

          def frac_to_millis(n: Int, digits: Int) -> Int
            if digits == 3 then n
            else if digits < 3 then n * pow10(3 - digits)
            else n / pow10(digits - 3)
            end end
          end

          def pow10(n: Int) -> Int
            if n <= 0 then 1 else 10 * pow10(n - 1) end
          end

          def combine(d: Calendar.Date, hour: Int, minute: Int, second: Int, sub_ms: Int) -> Instant
            day_count = Calendar.to_rata_die(d) - 719163
            Instant(day_count * 86400000 + hour * 3600000 + minute * 60000 + second * 1000 + sub_ms)
          end

          def compare_instant(a: Instant, b: Instant) -> Ordering
            Instant(ams) = a
            Instant(bms) = b
            compare(ams, bms)
          end

          def instant_eq(a: Instant, b: Instant) -> Bool
            Instant(ams) = a
            Instant(bms) = b
            ams == bms
          end

          implements Comparable(Instant) with
            compare: compare_instant
          end

          implements Eq(Instant) with
            (==): instant_eq
          end
          JADE
      end
    end
  end
end
