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
                                now, from_millis, to_millis,
                                add, diff,
                                to_iso_string, from_iso_string,
                                to_date)

          struct Instant  = { millis: Int }
          struct Duration = { millis: Int }

          uses Jade::Clock::Runtime with
            now_raw: Task({ millis: Int }, Never)
          end

          def now() -> Task(Instant, Never)
            raw <- now_raw()
            Task.succeed(Instant(raw.millis))
          end

          def from_millis(n: Int) -> Instant
            Instant(n)
          end

          def to_millis(i: Instant) -> Int
            i.millis
          end

          def add(i: Instant, d: Duration) -> Instant
            Instant(i.millis + d.millis)
          end

          def diff(a: Instant, b: Instant) -> Duration
            Duration(b.millis - a.millis)
          end

          def to_date(i: Instant) -> Calendar.Date
            Calendar.from_rata_die(floor_div(i.millis, 86400000) + 719163)
          end

          def floor_div(a: Int, b: Int) -> Int
            q = a / b
            if a < 0 && mod(a, b) != 0 then q - 1 else q end
          end

          def to_iso_string(i: Instant) -> String
            d = to_date(i)
            day_ms = mod(i.millis, 86400000)
            secs = day_ms / 1000
            hour = secs / 3600
            minute = mod(secs / 60, 60)
            second = mod(secs, 60)
            Calendar.to_iso_string(d) ++ "T"
              ++ pad2(hour) ++ ":" ++ pad2(minute) ++ ":" ++ pad2(second) ++ "Z"
          end

          def pad2(n: Int) -> String
            s = String.from_int(n)
            if String.length(s) < 2 then "0" ++ s else s end
          end

          def from_iso_string(s: String) -> Result(Instant, String)
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
            days = Calendar.to_rata_die(d) - 719163
            Instant(days * 86400000 + hour * 3600000 + minute * 60000 + second * 1000 + sub_ms)
          end

          def compare_instant(a: Instant, b: Instant) -> Ordering
            compare(a.millis, b.millis)
          end

          def instant_eq(a: Instant, b: Instant) -> Bool
            a.millis == b.millis
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
