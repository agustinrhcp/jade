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
          end


          def today -> Task(Date, Never)
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
            in Jan then 1
            in Feb then 2
            in Mar then 3
            in Apr then 4
            in May then 5
            in Jun then 6
            in Jul then 7
            in Aug then 8
            in Sep then 9
            in Oct then 10
            in Nov then 11
            in Dec then 12
            end
          end


          def month_from_int(i: Int) -> Month
            case i
            in 1 then Jan
            in 2 then Feb
            in 3 then Mar
            in 4 then Apr
            in 5 then May
            in 6 then Jun
            in 7 then Jul
            in 8 then Aug
            in 9 then Sep
            in 10 then Oct
            in 11 then Nov
            in 12 then Dec
            else Jan
            end
          end


          def weekday_to_int(w: Weekday) -> Int
            case w
            in Mon then 1
            in Tue then 2
            in Wed then 3
            in Thu then 4
            in Fri then 5
            in Sat then 6
            in Sun then 7
            end
          end


          def weekday_from_int(i: Int) -> Weekday
            case i
            in 1 then Mon
            in 2 then Tue
            in 3 then Wed
            in 4 then Thu
            in 5 then Fri
            in 6 then Sat
            in 7 then Sun
            else Mon
            end
          end


          def days_in_month(y: Int, m: Month) -> Int
            case m
            in Jan then 31
            in Feb then leap?(y) ? 29 : 28
            in Mar then 31
            in Apr then 30
            in May then 31
            in Jun then 30
            in Jul then 31
            in Aug then 31
            in Sep then 30
            in Oct then 31
            in Nov then 30
            in Dec then 31
            end
          end


          def leap?(y: Int) -> Bool
            (mod(y, 4) == 0) && ((mod(y, 100) != 0) || (mod(y, 400) == 0))
          end


          def days_before_year(y: Int) -> Int
            n = y - 1
            n * 365 + n / 4 - n / 100 + n / 400
          end


          def days_before_month(y: Int, m: Month) -> Int
            mi = month_to_int(m)
            base = (case mi
            in 1 then 0
            in 2 then 31
            in 3 then 59
            in 4 then 90
            in 5 then 120
            in 6 then 151
            in 7 then 181
            in 8 then 212
            in 9 then 243
            in 10 then 273
            in 11 then 304
            in 12 then 334
            else 0
            end)
            mi > 2 && leap?(y) ? base + 1 : base
          end


          def to_rata_die(d: Date) -> Int
            days_before_year(d.year) + days_before_month(d.year, d.month) + d.day
          end


          def weekday(d: Date) -> Weekday
            weekday_from_int(mod(to_rata_die(d) - 1, 7) + 1)
          end


          def pad_to(s: String, width: Int) -> String
            len = String.length(s)
            len < width ? String.repeat("0", width - len) ++ s : s
          end


          def to_iso_string(d: Date) -> String
            pad_to(String.from_int(d.year), 4)
              ++ "-"
              ++ pad_to(String.from_int(month_to_int(d.month)), 2)
              ++ "-"
              ++ pad_to(String.from_int(d.day), 2)
          end


          def from_iso_string(s: String) -> Result(Date, String)
            case String.split(s, "-")
            in [y, m, day_str]
              case (String.to_int(y), String.to_int(m), String.to_int(day_str))
              in (Just(yi), Just(mi), Just(di))
                Ok(from_calendar_date(yi, month_from_int(mi), di))
              else Err("invalid ISO date: " ++ s)
              end
            else Err("invalid ISO date: " ++ s)
            end
          end


          def add(d: Date, unit: Unit, n: Int) -> Date
            case unit
            in Days then add_days(d, n)
            in Weeks then add_days(d, n * 7)
            in Months then add_months(d, n)
            in Years then add_months(d, n * 12)
            end
          end


          def add_days(d: Date, n: Int) -> Date
            from_rata_die(to_rata_die(d) + n)
          end


          def add_months(d: Date, n: Int) -> Date
            total = month_to_int(d.month) - 1 + n
            new_year = d.year + total / 12
            new_month = month_from_int(mod(total, 12) + 1)
            from_calendar_date(
              new_year,
              new_month,
              min(d.day, days_in_month(new_year, new_month)),
            )
          end


          def min(a: Int, b: Int) -> Int
            a < b ? a : b
          end


          def diff(a: Date, b: Date, unit: Unit) -> Int
            case unit
            in Days then to_rata_die(b) - to_rata_die(a)
            in Weeks then (to_rata_die(b) - to_rata_die(a)) / 7
            in Months then calendar_months(a, b)
            in Years then calendar_months(a, b) / 12
            end
          end


          def calendar_months(a: Date, b: Date) -> Int
            raw = (b.year - a.year) * 12 + (month_to_int(b.month) - month_to_int(a.month))
            raw > 0 && b.day < a.day ? raw - 1 : raw < 0 && b.day > a.day ? raw + 1 : raw
          end


          def from_rata_die(rd: Int) -> Date
            y = bump_year(rd, (rd - 1) / 366 + 1)
            doy = rd - days_before_year(y)
            case search_month(y, doy, 12)
            in (m, d) then from_calendar_date(y, m, d)
            end
          end


          def bump_year(rd: Int, y: Int) -> Int
            days_before_year(y + 1) < rd ? bump_year(rd, y + 1) : y
          end


          def search_month(y: Int, doy: Int, mi: Int) -> (Month, Int)
            m = month_from_int(mi)
            offset = days_before_month(y, m)
            doy > offset ? (m, doy - offset) : search_month(y, doy, mi - 1)
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
            in EQ
              case compare_month(a.month, b.month)
              in EQ then compare(a.day, b.day)
              in o then o
              end
            in o then o
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
            decoder: -> { Decode.string |> Decode.and_then(parse_date) }
          end


          implements Encodable(Date) with
            encoder: (d) -> { Encode.string(to_iso_string(d)) }
          end
        JADE
      end
    end
  end
end
