require 'jade/stdlib/compiled'

module Jade
  module Stdlib
    module Calendar
      extend self
      extend Compiled

      def uri
        'calendar.jd'
      end

      def imports
        [Basics, Maybe, Result, Task, String, Tuple, Decode, Encode]
      end

      def default_imports
        []
      end

      def code
        <<~JADE
          module Calendar exposing (
            Date,
            Month(..),
            Unit(..),
            Weekday(..),
            add,
            day,
            diff,
            from_calendar_date,
            from_iso_string,
            from_rata_die,
            month,
            month_from_int,
            month_to_int,
            to_iso_string,
            to_rata_die,
            today,
            weekday,
            weekday_from_int,
            weekday_to_int,
            year,
          )

          import Decode exposing (Decodable, Decoder, Value)
          import Encode exposing (Encodable)


          type Month
            = Jan
            | Feb
            | Mar
            | Apr
            | May
            | Jun
            | Jul
            | Aug
            | Sep
            | Oct
            | Nov
            | Dec


          type Weekday
            = Mon
            | Tue
            | Wed
            | Thu
            | Fri
            | Sat
            | Sun


          type Unit
            = Years
            | Months
            | Weeks
            | Days


          struct Date = {
            year: Int,
            month: Month,
            day: Int
          }


          uses Jade::Calendar::Runtime with
            today_raw : Task({ year: Int, month: Int, day: Int }, Never)


          def today -> Task(Date, Never)
            raw <- today_raw()

            Task.succeed(Date(raw.year, month_from_int(raw.month), raw.day))


          def from_calendar_date(y: Int, m: Month, d: Int) -> Date
            Date(y, m, d)


          def year(d: Date) -> Int
            d.year


          def month(d: Date) -> Month
            d.month


          def day(d: Date) -> Int
            d.day


          def month_to_int(m: Month) -> Int
            case m
            of Jan -> 1
            of Feb -> 2
            of Mar -> 3
            of Apr -> 4
            of May -> 5
            of Jun -> 6
            of Jul -> 7
            of Aug -> 8
            of Sep -> 9
            of Oct -> 10
            of Nov -> 11
            of Dec -> 12


          def month_from_int(i: Int) -> Month
            case i
            of 1 -> Jan
            of 2 -> Feb
            of 3 -> Mar
            of 4 -> Apr
            of 5 -> May
            of 6 -> Jun
            of 7 -> Jul
            of 8 -> Aug
            of 9 -> Sep
            of 10 -> Oct
            of 11 -> Nov
            of 12 -> Dec
            of _ -> Jan


          def weekday_to_int(w: Weekday) -> Int
            case w
            of Mon -> 1
            of Tue -> 2
            of Wed -> 3
            of Thu -> 4
            of Fri -> 5
            of Sat -> 6
            of Sun -> 7


          def weekday_from_int(i: Int) -> Weekday
            case i
            of 1 -> Mon
            of 2 -> Tue
            of 3 -> Wed
            of 4 -> Thu
            of 5 -> Fri
            of 6 -> Sat
            of 7 -> Sun
            of _ -> Mon


          def days_in_month(y: Int, m: Month) -> Int
            case m
            of Jan -> 31
            of Feb -> if leap?(y) then 29 else 28
            of Mar -> 31
            of Apr -> 30
            of May -> 31
            of Jun -> 30
            of Jul -> 31
            of Aug -> 31
            of Sep -> 30
            of Oct -> 31
            of Nov -> 30
            of Dec -> 31


          def leap?(y: Int) -> Bool
            (mod(y, 4) == 0) && ((mod(y, 100) != 0) || (mod(y, 400) == 0))


          def days_before_year(y: Int) -> Int
            n = y - 1

            n * 365 + n / 4 - n / 100 + n / 400


          def days_before_month(y: Int, m: Month) -> Int
            mi = month_to_int(m)
            base = (case mi
            of 1 -> 0
            of 2 -> 31
            of 3 -> 59
            of 4 -> 90
            of 5 -> 120
            of 6 -> 151
            of 7 -> 181
            of 8 -> 212
            of 9 -> 243
            of 10 -> 273
            of 11 -> 304
            of 12 -> 334
            of _ -> 0)

            if mi > 2 && leap?(y) then base + 1 else base


          def to_rata_die(d: Date) -> Int
            days_before_year(d.year) + days_before_month(d.year, d.month) + d.day


          def weekday(d: Date) -> Weekday
            weekday_from_int(mod(to_rata_die(d) - 1, 7) + 1)


          def pad_to(s: String, width: Int) -> String
            len = String.length(s)

            if len < width then String.repeat("0", width - len) ++ s else s


          def to_iso_string(d: Date) -> String
            pad_to(String.from_int(d.year), 4)
              ++ "-"
              ++ pad_to(String.from_int(month_to_int(d.month)), 2)
              ++ "-"
              ++ pad_to(String.from_int(d.day), 2)


          def from_iso_string(s: String) -> Result(Date, String)
            case String.split(s, "-")
            of [y, m, day_str] -> (
              case (String.to_int(y), String.to_int(m), String.to_int(day_str))
              of (Just(yi), Just(mi), Just(di)) ->
                Ok(from_calendar_date(yi, month_from_int(mi), di))
              of _ -> Err("invalid ISO date: " ++ s)
            )
            of _ -> Err("invalid ISO date: " ++ s)


          def add(d: Date, unit: Unit, n: Int) -> Date
            case unit
            of Days -> add_days(d, n)
            of Weeks -> add_days(d, n * 7)
            of Months -> add_months(d, n)
            of Years -> add_months(d, n * 12)


          def add_days(d: Date, n: Int) -> Date
            from_rata_die(to_rata_die(d) + n)


          def add_months(d: Date, n: Int) -> Date
            total = month_to_int(d.month) - 1 + n
            new_year = d.year + total / 12
            new_month = month_from_int(mod(total, 12) + 1)

            from_calendar_date(
              new_year,
              new_month,
              min(d.day, days_in_month(new_year, new_month)),
            )


          def min(a: Int, b: Int) -> Int
            if a < b then a else b


          def diff(a: Date, b: Date, unit: Unit) -> Int
            case unit
            of Days -> to_rata_die(b) - to_rata_die(a)
            of Weeks -> (to_rata_die(b) - to_rata_die(a)) / 7
            of Months -> calendar_months(a, b)
            of Years -> calendar_months(a, b) / 12


          def calendar_months(a: Date, b: Date) -> Int
            raw = (b.year - a.year) * 12 + (month_to_int(b.month) - month_to_int(a.month))

            if raw > 0 && b.day < a.day then raw - 1
            else if raw < 0 && b.day > a.day then raw + 1
            else raw


          def from_rata_die(rd: Int) -> Date
            y = bump_year(rd, (rd - 1) / 366 + 1)
            doy = rd - days_before_year(y)

            case search_month(y, doy, 12)
            of (m, d) -> from_calendar_date(y, m, d)


          def bump_year(rd: Int, y: Int) -> Int
            if days_before_year(y + 1) < rd then bump_year(rd, y + 1) else y


          def search_month(y: Int, doy: Int, mi: Int) -> (Month, Int)
            m = month_from_int(mi)
            offset = days_before_month(y, m)

            if doy > offset then (m, doy - offset) else search_month(y, doy, mi - 1)


          def compare_month(a: Month, b: Month) -> Ordering
            compare(month_to_int(a), month_to_int(b))


          def month_eq(a: Month, b: Month) -> Bool
            month_to_int(a) == month_to_int(b)


          implements Comparable(Month) with
            compare: compare_month


          implements Eq(Month) with
            (==): month_eq


          def compare_date(a: Date, b: Date) -> Ordering
            case compare(a.year, b.year)
            of EQ -> (
              case compare_month(a.month, b.month)
              of EQ -> compare(a.day, b.day)
              of o -> o
            )
            of o -> o


          def date_eq(a: Date, b: Date) -> Bool
            a.year == b.year && a.month == b.month && a.day == b.day


          implements Comparable(Date) with
            compare: compare_date


          implements Eq(Date) with
            (==): date_eq


          def parse_date(s: String) -> Decoder(Date)
            Decode.from_result(from_iso_string(s))


          implements Decodable(Date) with
            decoder: -> { Decode.string |> Decode.and_then(parse_date) }


          implements Encodable(Date) with
            encoder: (d) -> { Encode.string(to_iso_string(d)) }
        JADE
      end
    end
  end
end
