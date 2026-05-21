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
        [Basics, Maybe, Result, Task, String, Tuple, Decode, Encode, Calendar]
      end

      def default_imports
        []
      end

      def code
        <<~JADE
          module Clock exposing (
            Duration,
            Instant,
            add,
            at_time,
            days,
            diff,
            epoch,
            from_iso,
            hours,
            in_days,
            in_hours,
            in_millis,
            in_minutes,
            in_seconds,
            millis,
            minutes,
            now,
            on_date,
            parts,
            seconds,
            to_iso,
          )

          import Decode exposing (Decodable, Decoder, Value)
          import Encode exposing (Encodable)


          type Instant = Instant(Int)


          type Duration = Duration(Int)


          uses Jade::Clock::Runtime with
            now_raw : Task({ millis: Int }, Never)


          def now -> Task(Instant, Never)
            raw <- now_raw()

            Task.succeed(Instant(raw.millis))


          def epoch -> Instant
            Instant(0)


          def millis(n: Int) -> Duration
            Duration(n)


          def in_millis(d: Duration) -> Int
            Duration(n) = d

            n


          def seconds(n: Int) -> Duration
            Duration(n * 1000)


          def in_seconds(d: Duration) -> Int
            in_millis(d) / 1000


          def minutes(n: Int) -> Duration
            Duration(n * 60000)


          def in_minutes(d: Duration) -> Int
            in_millis(d) / 60000


          def hours(n: Int) -> Duration
            Duration(n * 3600000)


          def in_hours(d: Duration) -> Int
            in_millis(d) / 3600000


          def days(n: Int) -> Duration
            Duration(n * 86400000)


          def in_days(d: Duration) -> Int
            in_millis(d) / 86400000


          def parts(d: Duration) -> {
            days: Int,
            hours: Int,
            minutes: Int,
            seconds: Int,
            millis: Int,
          }
            ms = in_millis(d)

            {
              days: ms / 86400000,
              hours: mod(ms, 86400000) / 3600000,
              minutes: mod(ms, 3600000) / 60000,
              seconds: mod(ms, 60000) / 1000,
              millis: mod(ms, 1000),
            }


          def add(i: Instant, d: Duration) -> Instant
            Instant(ms) = i

            Instant(ms + in_millis(d))


          def diff(a: Instant, b: Instant) -> Duration
            Instant(ams) = a
            Instant(bms) = b

            Duration(bms - ams)


          def on_date(i: Instant) -> Calendar.Date
            Instant(ms) = i

            Calendar.from_rata_die(floor_div(ms, 86400000) + 719163)


          def at_time(i: Instant) -> {
            hour: Int,
            minute: Int,
            second: Int,
            millisecond: Int,
          }
            Instant(ms) = i
            day_ms = mod(ms, 86400000)

            {
              hour: day_ms / 3600000,
              minute: mod(day_ms, 3600000) / 60000,
              second: mod(day_ms, 60000) / 1000,
              millisecond: mod(day_ms, 1000),
            }


          def floor_div(a: Int, b: Int) -> Int
            q = a / b

            if a < 0 && mod(a, b) != 0 then q - 1 else q


          def to_iso(i: Instant) -> String
            d = on_date(i)
            tod = at_time(i)

            Calendar.to_iso_string(d)
              ++ "T"
              ++ pad2(tod.hour)
              ++ ":"
              ++ pad2(tod.minute)
              ++ ":"
              ++ pad2(tod.second)
              ++ "Z"


          def pad2(n: Int) -> String
            s = String.from_int(n)

            if String.length(s) < 2 then "0" ++ s else s


          def from_iso(s: String) -> Result(Instant, String)
            case split_dt(s)
            of Just((date_part, time_part)) -> (
              case (Calendar.from_iso_string(date_part), parse_time(time_part))
              of (Ok(d), Ok((h, m, sec, sub))) -> Ok(combine(d, h, m, sec, sub))
              of _ -> Err("invalid timestamp: " ++ s)
            )
            of Nothing -> Err("invalid timestamp: " ++ s)


          def split_dt(s: String) -> Maybe((String, String))
            case String.split(s, "T")
            of [d, t] -> Just((d, t))
            of _ -> (
              case String.split(s, " ")
              of [d, t] -> Just((d, t))
              of _ -> Nothing
            )


          def parse_time(s: String) -> Result((Int, Int, Int, Int), String)
            case String.split(strip_z(s), ":")
            of [h, m, sec_part] -> (
              case (String.to_int(h), String.to_int(m), parse_seconds(sec_part))
              of (Just(hi), Just(mi), Just((si, ms))) -> Ok((hi, mi, si, ms))
              of _ -> Err("bad time: " ++ s)
            )
            of _ -> Err("bad time: " ++ s)


          def strip_z(s: String) -> String
            case String.split(s, "Z")
            of [head, _] -> head
            of [head] -> head
            of _ -> s


          def parse_seconds(s: String) -> Maybe((Int, Int))
            case String.split(s, ".")
            of [secs] -> (
              case String.to_int(secs)
              of Just(si) -> Just((si, 0))
              of Nothing -> Nothing
            )
            of [secs, frac] -> (
              case (String.to_int(secs), String.to_int(frac))
              of (Just(si), Just(fi)) ->
                Just((si, frac_to_millis(fi, String.length(frac))))
              of _ -> Nothing
            )
            of _ -> Nothing


          def frac_to_millis(n: Int, digits: Int) -> Int
            if digits == 3 then n
            else if digits < 3 then n * pow10(3 - digits)
            else n / pow10(digits - 3)


          def pow10(n: Int) -> Int
            if n <= 0 then 1 else 10 * pow10(n - 1)


          def combine(
            d: Calendar.Date,
            hour: Int,
            minute: Int,
            second: Int,
            sub_ms: Int,
          ) -> Instant
            day_count = Calendar.to_rata_die(d) - 719163

            Instant(
              day_count * 86400000 + hour * 3600000 + minute * 60000 + second * 1000 + sub_ms,
            )


          def compare_instant(a: Instant, b: Instant) -> Ordering
            Instant(ams) = a
            Instant(bms) = b

            compare(ams, bms)


          def instant_eq(a: Instant, b: Instant) -> Bool
            Instant(ams) = a
            Instant(bms) = b

            ams == bms


          implements Comparable(Instant) with
            compare: compare_instant


          implements Eq(Instant) with
            (==): instant_eq


          def parse_instant(s: String) -> Decoder(Instant)
            Decode.from_result(from_iso(s))


          implements Decodable(Instant) with
            decoder: -> { Decode.string |> Decode.and_then(parse_instant) }


          implements Encodable(Instant) with
            encoder: (i) -> { Encode.string(to_iso(i)) }


          implements Decodable(Duration) with
            decoder: -> { Decode.map(Decode.int, Duration) }


          implements Encodable(Duration) with
            encoder: (d) -> { Encode.int(in_millis(d)) }
          JADE
      end
    end
  end
end
