require 'spec_helper'

require 'jade'
require 'jade/module_loader'

module Jade
  describe 'Calendar' do
    include_context 'with test compiler'

    let(:source) do
      <<~JADE
        module Use exposing(today, build, year_of, month_of, day_of, weekday_of,
                            describe_month, describe_weekday, before, equal,
                            month_round_trip,
                            iso, parse_iso, shift, span)

        import Calendar exposing(Date, Month(..), Weekday(..), Unit(..))

        def today() -> Task(Date, Never)
          Calendar.today
        end

        def build(y: Int, m: Month, d: Int) -> Date
          Calendar.from_calendar_date(y, m, d)
        end

        def year_of(d: Date) -> Int
          Calendar.year(d)
        end

        def month_of(d: Date) -> Month
          Calendar.month(d)
        end

        def day_of(d: Date) -> Int
          Calendar.day(d)
        end

        def describe_month(m: Month) -> String
          case m
          of Jan then "January"
          of Feb then "February"
          of Mar then "March"
          of Apr then "April"
          of May then "May"
          of Jun then "June"
          of Jul then "July"
          of Aug then "August"
          of Sep then "September"
          of Oct then "October"
          of Nov then "November"
          of Dec then "December"
          end
        end

        def before(a: Date, b: Date) -> Bool
          a < b
        end

        def equal(a: Date, b: Date) -> Bool
          a == b
        end

        def month_round_trip(i: Int) -> Int
          Calendar.month_to_int(Calendar.month_from_int(i))
        end

        def weekday_of(d: Date) -> Weekday
          Calendar.weekday(d)
        end

        def describe_weekday(w: Weekday) -> String
          case w
          of Mon then "Monday"
          of Tue then "Tuesday"
          of Wed then "Wednesday"
          of Thu then "Thursday"
          of Fri then "Friday"
          of Sat then "Saturday"
          of Sun then "Sunday"
          end
        end

        def iso(d: Date) -> String
          Calendar.to_iso_string(d)
        end

        def parse_iso(s: String) -> Result(Date, String)
          Calendar.from_iso_string(s)
        end

        def shift(d: Date, unit: Unit, n: Int) -> Date
          Calendar.add(d, unit, n)
        end

        def span(a: Date, b: Date, unit: Unit) -> Int
          Calendar.diff(a, b, unit)
        end
      JADE
    end

    before { test_compiler.require('use', source) }

    it 'today() returns a Task that resolves to a Date struct' do
      result = Use.today.call.run
      expect(result).to be_a(Result::Ok)
      d = result._1
      expect(d.year).to be_a(Integer)
      expect(d.day).to be_a(Integer)
      expect(d.month.class.name).to start_with('Jade::Calendar::')
    end

    it 'builds a Date from year, Month, day' do
      d = Use.build.call(2026, Calendar::Mar[], 15)
      expect(d.year).to eql 2026
      expect(d.month).to eql Calendar::Mar[]
      expect(d.day).to eql 15
    end

    it 'extracts the year' do
      d = Use.build.call(2026, Calendar::May[], 4)
      expect(Use.year_of.call(d)).to eql 2026
    end

    it 'extracts the month' do
      d = Use.build.call(2026, Calendar::May[], 4)
      expect(Use.month_of.call(d)).to eql Calendar::May[]
    end

    it 'extracts the day' do
      d = Use.build.call(2026, Calendar::May[], 4)
      expect(Use.day_of.call(d)).to eql 4
    end

    it 'pattern-matches Month variants in user code' do
      expect(Use.describe_month.call(Calendar::Jan[])).to eql 'January'
      expect(Use.describe_month.call(Calendar::Dec[])).to eql 'December'
    end

    it 'compares two dates via the Comparable instance (year differs)' do
      a = Use.build.call(2025, Calendar::May[], 4)
      b = Use.build.call(2026, Calendar::May[], 4)
      expect(Use.before.call(a, b)).to be true
      expect(Use.before.call(b, a)).to be false
    end

    it 'compares two dates via the Comparable instance (month differs)' do
      a = Use.build.call(2026, Calendar::Jan[], 31)
      b = Use.build.call(2026, Calendar::Feb[], 1)
      expect(Use.before.call(a, b)).to be true
    end

    it 'compares two dates via the Comparable instance (day differs)' do
      a = Use.build.call(2026, Calendar::May[], 4)
      b = Use.build.call(2026, Calendar::May[], 5)
      expect(Use.before.call(a, b)).to be true
    end

    it 'reports equal dates via the Eq instance' do
      a = Use.build.call(2026, Calendar::May[], 4)
      b = Use.build.call(2026, Calendar::May[], 4)
      expect(Use.equal.call(a, b)).to be true
    end

    it 'reports unequal dates via the Eq instance' do
      a = Use.build.call(2026, Calendar::May[], 4)
      b = Use.build.call(2026, Calendar::May[], 5)
      expect(Use.equal.call(a, b)).to be false
    end

    it 'round-trips Month <-> Int' do
      (1..12).each do |i|
        expect(Use.month_round_trip.call(i)).to eql i
      end
    end

    it 'computes weekday for a known date (2026-05-04 is a Monday)' do
      d = Use.build.call(2026, Calendar::May[], 4)
      expect(Use.weekday_of.call(d)).to eql Calendar::Mon[]
    end

    it 'computes weekday for a known date (2026-05-03 is a Sunday)' do
      d = Use.build.call(2026, Calendar::May[], 3)
      expect(Use.weekday_of.call(d)).to eql Calendar::Sun[]
    end

    it 'pattern-matches Weekday variants' do
      expect(Use.describe_weekday.call(Calendar::Mon[])).to eql 'Monday'
      expect(Use.describe_weekday.call(Calendar::Sun[])).to eql 'Sunday'
    end

    it 'formats a Date as an ISO 8601 string' do
      d = Use.build.call(2026, Calendar::May[], 4)
      expect(Use.iso.call(d)).to eql '2026-05-04'
    end

    it 'pads single-digit month and day' do
      d = Use.build.call(2026, Calendar::Jan[], 9)
      expect(Use.iso.call(d)).to eql '2026-01-09'
    end

    it 'parses an ISO 8601 string into a Date' do
      result = Use.parse_iso.call('2026-05-04')
      expect(result).to be_a(Result::Ok)
      expect(result._1.year).to eql 2026
      expect(result._1.month).to eql Calendar::May[]
      expect(result._1.day).to eql 4
    end

    it 'returns Err for an invalid ISO string' do
      expect(Use.parse_iso.call('not-a-date')).to be_a(Result::Err)
    end

    it 'add(Days) advances the date' do
      d = Use.build.call(2026, Calendar::May[], 4)
      expect(Use.shift.call(d, Calendar::Days[], 10))
        .to eql Use.build.call(2026, Calendar::May[], 14)
    end

    it 'add(Days) crosses a month boundary' do
      d = Use.build.call(2026, Calendar::Jan[], 30)
      expect(Use.shift.call(d, Calendar::Days[], 5))
        .to eql Use.build.call(2026, Calendar::Feb[], 4)
    end

    it 'add(Months) advances by months' do
      d = Use.build.call(2026, Calendar::May[], 4)
      expect(Use.shift.call(d, Calendar::Months[], 3))
        .to eql Use.build.call(2026, Calendar::Aug[], 4)
    end

    it 'add(Months) clamps to month length' do
      d = Use.build.call(2026, Calendar::Jan[], 31)
      expect(Use.shift.call(d, Calendar::Months[], 1))
        .to eql Use.build.call(2026, Calendar::Feb[], 28)
    end

    it 'add(Years) advances by years' do
      d = Use.build.call(2026, Calendar::May[], 4)
      expect(Use.shift.call(d, Calendar::Years[], 5))
        .to eql Use.build.call(2031, Calendar::May[], 4)
    end

    it 'add(Years) handles leap-year clamping' do
      d = Use.build.call(2024, Calendar::Feb[], 29)
      expect(Use.shift.call(d, Calendar::Years[], 1))
        .to eql Use.build.call(2025, Calendar::Feb[], 28)
    end

    it 'diff(Days) counts whole days between dates' do
      a = Use.build.call(2026, Calendar::May[], 4)
      b = Use.build.call(2026, Calendar::May[], 14)
      expect(Use.span.call(a, b, Calendar::Days[])).to eql 10
    end

    it 'diff(Months) counts full months between dates' do
      a = Use.build.call(2026, Calendar::Jan[], 15)
      b = Use.build.call(2026, Calendar::Apr[], 14)
      expect(Use.span.call(a, b, Calendar::Months[])).to eql 2
    end

    context 'Encodable / Decodable' do
      let(:source) do
        <<~JADE
          module Json exposing(date_to_json, date_from_json)

          import Calendar exposing(Date, Month(..))
          import Encode
          import Decode exposing(DecodeError)

          def date_to_json(d: Date) -> String
            Encode.encode_to_string(Encode.encode(d))
          end

          def date_from_json(s: String) -> Result(Date, DecodeError)
            Decode.from_json(s)
          end
        JADE
      end

      before { test_compiler.require('json', source) }

      it 'encodes a Date as an ISO 8601 string' do
        d = Use.build.call(2026, Calendar::May[], 4)
        expect(Json.date_to_json.call(d)).to eql '"2026-05-04"'
      end

      it 'decodes a Date from an ISO 8601 string' do
        result = Json.date_from_json.call('"2026-05-04"')
        expect(result).to be_a(Result::Ok)
        expect(result._1).to have_attributes(year: 2026, day: 4)
      end

      it 'fails decoding an invalid ISO date' do
        result = Json.date_from_json.call('"not-a-date"')
        expect(result).to be_a(Result::Err)
      end
    end
  end
end
