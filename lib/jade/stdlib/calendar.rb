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
          module Calendar exposing(Date, Month(..), Weekday(..), Unit(..),
                                   today, from_calendar_date,
                                   year, month, day, weekday,
                                   month_to_int, month_from_int,
                                   weekday_to_int, weekday_from_int,
                                   to_iso_string, from_iso_string,
                                   to_rata_die, from_rata_die,
                                   add, diff)

          import Decode exposing(Decoder, Decodable, Value)
          import Encode exposing(Encodable)

          type Month   = Jan | Feb | Mar | Apr | May | Jun
                       | Jul | Aug | Sep | Oct | Nov | Dec

          type Weekday = Mon | Tue | Wed | Thu | Fri | Sat | Sun

          type Unit    = Years | Months | Weeks | Days

          struct Date  = { year: Int, month: Month, day: Int }

          uses Jade::Calendar::Runtime with
            today_raw: Task({ year: Int, month: Int, day: Int }, Never)
          end

          def today() -> Task(Date, Never)
            raw <- today_raw()
            Task.succeed(Date(raw.year, month_from_int(raw.month), raw.day))
          end

          def from_calendar_date(y: Int, m: Month, d: Int) -> Date
            Date(y, m, d)
          end

          def year(d: Date) -> Int
            d.year
          end

          def month(d: Date) -> Month
            d.month
          end

          def day(d: Date) -> Int
            d.day
          end

          def month_to_int(m: Month) -> Int
            case m
            of Jan then 1
            of Feb then 2
            of Mar then 3
            of Apr then 4
            of May then 5
            of Jun then 6
            of Jul then 7
            of Aug then 8
            of Sep then 9
            of Oct then 10
            of Nov then 11
            of Dec then 12
            end
          end

          def month_from_int(i: Int) -> Month
            case i
            of 1  then Jan
            of 2  then Feb
            of 3  then Mar
            of 4  then Apr
            of 5  then May
            of 6  then Jun
            of 7  then Jul
            of 8  then Aug
            of 9  then Sep
            of 10 then Oct
            of 11 then Nov
            of 12 then Dec
            of _  then Jan
            end
          end

          def weekday_to_int(w: Weekday) -> Int
            case w
            of Mon then 1
            of Tue then 2
            of Wed then 3
            of Thu then 4
            of Fri then 5
            of Sat then 6
            of Sun then 7
            end
          end

          def weekday_from_int(i: Int) -> Weekday
            case i
            of 1 then Mon
            of 2 then Tue
            of 3 then Wed
            of 4 then Thu
            of 5 then Fri
            of 6 then Sat
            of 7 then Sun
            of _ then Mon
            end
          end

          def days_in_month(y: Int, m: Month) -> Int
            case m
            of Jan then 31
            of Feb then if is_leap(y) then 29 else 28 end
            of Mar then 31
            of Apr then 30
            of May then 31
            of Jun then 30
            of Jul then 31
            of Aug then 31
            of Sep then 30
            of Oct then 31
            of Nov then 30
            of Dec then 31
            end
          end

          def is_leap(y: Int) -> Bool
            (mod(y, 4) == 0) && ((mod(y, 100) != 0) || (mod(y, 400) == 0))
          end

          def days_before_year(y: Int) -> Int
            n = y - 1
            n * 365 + n / 4 - n / 100 + n / 400
          end

          def days_before_month(y: Int, m: Month) -> Int
            mi = month_to_int(m)
            base = case mi
                   of 1  then 0
                   of 2  then 31
                   of 3  then 59
                   of 4  then 90
                   of 5  then 120
                   of 6  then 151
                   of 7  then 181
                   of 8  then 212
                   of 9  then 243
                   of 10 then 273
                   of 11 then 304
                   of 12 then 334
                   of _  then 0
                   end
            if mi > 2 && is_leap(y) then base + 1 else base end
          end

          def to_rata_die(d: Date) -> Int
            days_before_year(d.year) + days_before_month(d.year, d.month) + d.day
          end

          def weekday(d: Date) -> Weekday
            weekday_from_int(mod(to_rata_die(d) - 1, 7) + 1)
          end

          def pad_to(s: String, width: Int) -> String
            len = String.length(s)
            if len < width then String.repeat("0", width - len) ++ s else s end
          end

          def to_iso_string(d: Date) -> String
            pad_to(String.from_int(d.year), 4)
              ++ "-" ++ pad_to(String.from_int(month_to_int(d.month)), 2)
              ++ "-" ++ pad_to(String.from_int(d.day), 2)
          end

          def from_iso_string(s: String) -> Result(Date, String)
            case String.split(s, "-")
            of [y, m, day_str] then
              case (String.to_int(y), String.to_int(m), String.to_int(day_str))
              of (Just(yi), Just(mi), Just(di)) then
                Ok(from_calendar_date(yi, month_from_int(mi), di))
              of _ then Err("invalid ISO date: " ++ s)
              end
            of _ then Err("invalid ISO date: " ++ s)
            end
          end

          def add(d: Date, unit: Unit, n: Int) -> Date
            case unit
            of Days   then add_days(d, n)
            of Weeks  then add_days(d, n * 7)
            of Months then add_months(d, n)
            of Years  then add_months(d, n * 12)
            end
          end

          def add_days(d: Date, n: Int) -> Date
            from_rata_die(to_rata_die(d) + n)
          end

          def add_months(d: Date, n: Int) -> Date
            total = month_to_int(d.month) - 1 + n
            new_year = d.year + total / 12
            new_month = month_from_int(mod(total, 12) + 1)
            from_calendar_date(new_year, new_month, min(d.day, days_in_month(new_year, new_month)))
          end

          def min(a: Int, b: Int) -> Int
            if a < b then a else b end
          end

          def diff(a: Date, b: Date, unit: Unit) -> Int
            case unit
            of Days   then to_rata_die(b) - to_rata_die(a)
            of Weeks  then (to_rata_die(b) - to_rata_die(a)) / 7
            of Months then calendar_months(a, b)
            of Years  then calendar_months(a, b) / 12
            end
          end

          def calendar_months(a: Date, b: Date) -> Int
            raw = (b.year - a.year) * 12 + (month_to_int(b.month) - month_to_int(a.month))
            if raw > 0 && b.day < a.day then raw - 1
            else if raw < 0 && b.day > a.day then raw + 1
            else raw
            end end
          end

          def from_rata_die(rd: Int) -> Date
            y = bump_year(rd, (rd - 1) / 366 + 1)
            doy = rd - days_before_year(y)
            case search_month(y, doy, 12)
            of (m, d) then from_calendar_date(y, m, d)
            end
          end

          def bump_year(rd: Int, y: Int) -> Int
            if days_before_year(y + 1) < rd then bump_year(rd, y + 1) else y end
          end

          def search_month(y: Int, doy: Int, mi: Int) -> (Month, Int)
            m = month_from_int(mi)
            offset = days_before_month(y, m)
            if doy > offset then (m, doy - offset) else search_month(y, doy, mi - 1) end
          end

          def compare_month(a: Month, b: Month) -> Ordering
            compare(month_to_int(a), month_to_int(b))
          end

          def month_eq(a: Month, b: Month) -> Bool
            month_to_int(a) == month_to_int(b)
          end

          implements Comparable(Month) with
            compare: compare_month
          end

          implements Eq(Month) with
            (==): month_eq
          end

          def compare_date(a: Date, b: Date) -> Ordering
            case compare(a.year, b.year)
            of EQ then
              case compare_month(a.month, b.month)
              of EQ then compare(a.day, b.day)
              of o then o
              end
            of o then o
            end
          end

          def date_eq(a: Date, b: Date) -> Bool
            a.year == b.year && a.month == b.month && a.day == b.day
          end

          implements Comparable(Date) with
            compare: compare_date
          end

          implements Eq(Date) with
            (==): date_eq
          end

          def parse_date(s: String) -> Decoder(Date)
            Decode.from_result(from_iso_string(s))
          end

          implements Decodable(Date) with
            decoder: () -> { Decode.string |> Decode.and_then(parse_date) }
          end

          implements Encodable(Date) with
            encoder: (d) -> { Encode.string(to_iso_string(d)) }
          end
        JADE
      end
    end
  end
end
