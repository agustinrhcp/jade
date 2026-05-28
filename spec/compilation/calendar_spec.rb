require 'spec_helper'

require 'jade'
require 'jade/module_loader'

module Jade
  describe 'Calendar' do
    include_context 'with test compiler'

    let(:source) do
      <<~JADE
        module Use exposing (
          before,
          build,
          day_of,
          describe_month,
          describe_weekday,
          equal,
          iso,
          month_of,
          month_round_trip,
          parse_iso,
          shift,
          span,
          today,
          weekday_of,
          year_of,
        )

        import Calendar exposing (Date, Month(..), Unit(..), Weekday(..))


        def today -> Task(Date, Never)
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
          in Jan then "January"
          in Feb then "February"
          in Mar then "March"
          in Apr then "April"
          in May then "May"
          in Jun then "June"
          in Jul then "July"
          in Aug then "August"
          in Sep then "September"
          in Oct then "October"
          in Nov then "November"
          in Dec then "December"
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
          in Mon then "Monday"
          in Tue then "Tuesday"
          in Wed then "Wednesday"
          in Thu then "Thursday"
          in Fri then "Friday"
          in Sat then "Saturday"
          in Sun then "Sunday"
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
      expect(Use::Internal.today.run).to be_ok(
        have_attributes(year: kind_of(Integer), day: kind_of(Integer))
      )
    end

    it 'builds a Date from year, Month, day' do
      d = Use::Internal.build(2026, Calendar::Mar[], 15)
      expect(d.year).to eql 2026
      expect(d.month).to be_mar
      expect(d.day).to eql 15
    end

    it 'extracts the year' do
      d = Use::Internal.build(2026, Calendar::May[], 4)
      expect(Use::Internal.year_of(d)).to eql 2026
    end

    it 'extracts the month' do
      d = Use::Internal.build(2026, Calendar::May[], 4)
      expect(Use::Internal.month_of(d)).to be_may
    end

    it 'extracts the day' do
      d = Use::Internal.build(2026, Calendar::May[], 4)
      expect(Use::Internal.day_of(d)).to eql 4
    end

    it 'pattern-matches Month variants in user code' do
      expect(Use::Internal.describe_month(Calendar::Jan[])).to eql 'January'
      expect(Use::Internal.describe_month(Calendar::Dec[])).to eql 'December'
    end

    it 'compares two dates via the Comparable instance (year differs)' do
      a = Use::Internal.build(2025, Calendar::May[], 4)
      b = Use::Internal.build(2026, Calendar::May[], 4)
      expect(Use::Internal.before(a, b)).to be true
      expect(Use::Internal.before(b, a)).to be false
    end

    it 'compares two dates via the Comparable instance (month differs)' do
      a = Use::Internal.build(2026, Calendar::Jan[], 31)
      b = Use::Internal.build(2026, Calendar::Feb[], 1)
      expect(Use::Internal.before(a, b)).to be true
    end

    it 'compares two dates via the Comparable instance (day differs)' do
      a = Use::Internal.build(2026, Calendar::May[], 4)
      b = Use::Internal.build(2026, Calendar::May[], 5)
      expect(Use::Internal.before(a, b)).to be true
    end

    it 'reports equal dates via the Eq instance' do
      a = Use::Internal.build(2026, Calendar::May[], 4)
      b = Use::Internal.build(2026, Calendar::May[], 4)
      expect(Use::Internal.equal(a, b)).to be true
    end

    it 'reports unequal dates via the Eq instance' do
      a = Use::Internal.build(2026, Calendar::May[], 4)
      b = Use::Internal.build(2026, Calendar::May[], 5)
      expect(Use::Internal.equal(a, b)).to be false
    end

    it 'round-trips Month <-> Int' do
      (1..12).each do |i|
        expect(Use.month_round_trip(i)).to eql i
      end
    end

    it 'computes weekday for a known date (2026-05-04 is a Monday)' do
      d = Use::Internal.build(2026, Calendar::May[], 4)
      expect(Use::Internal.weekday_of(d)).to be_mon
    end

    it 'computes weekday for a known date (2026-05-03 is a Sunday)' do
      d = Use::Internal.build(2026, Calendar::May[], 3)
      expect(Use::Internal.weekday_of(d)).to be_sun
    end

    it 'pattern-matches Weekday variants' do
      expect(Use::Internal.describe_weekday(Calendar::Mon[])).to eql 'Monday'
      expect(Use::Internal.describe_weekday(Calendar::Sun[])).to eql 'Sunday'
    end

    it 'formats a Date as an ISO 8601 string' do
      d = Use::Internal.build(2026, Calendar::May[], 4)
      expect(Use::Internal.iso(d)).to eql '2026-05-04'
    end

    it 'pads single-digit month and day' do
      d = Use::Internal.build(2026, Calendar::Jan[], 9)
      expect(Use::Internal.iso(d)).to eql '2026-01-09'
    end

    it 'parses an ISO 8601 string into a Date' do
      expect(Use::Internal.parse_iso('2026-05-04')).to be_ok(
        have_attributes(year: 2026, month: be_may, day: 4)
      )
    end

    it 'returns Err for an invalid ISO string' do
      expect(Use::Internal.parse_iso('not-a-date')).to be_err
    end

    it 'add(Days) advances the date' do
      d = Use::Internal.build(2026, Calendar::May[], 4)
      expect(Use::Internal.shift(d, Calendar::Days[], 10))
        .to eql Use::Internal.build(2026, Calendar::May[], 14)
    end

    it 'add(Days) crosses a month boundary' do
      d = Use::Internal.build(2026, Calendar::Jan[], 30)
      expect(Use::Internal.shift(d, Calendar::Days[], 5))
        .to eql Use::Internal.build(2026, Calendar::Feb[], 4)
    end

    it 'add(Months) advances by months' do
      d = Use::Internal.build(2026, Calendar::May[], 4)
      expect(Use::Internal.shift(d, Calendar::Months[], 3))
        .to eql Use::Internal.build(2026, Calendar::Aug[], 4)
    end

    it 'add(Months) clamps to month length' do
      d = Use::Internal.build(2026, Calendar::Jan[], 31)
      expect(Use::Internal.shift(d, Calendar::Months[], 1))
        .to eql Use::Internal.build(2026, Calendar::Feb[], 28)
    end

    it 'add(Years) advances by years' do
      d = Use::Internal.build(2026, Calendar::May[], 4)
      expect(Use::Internal.shift(d, Calendar::Years[], 5))
        .to eql Use::Internal.build(2031, Calendar::May[], 4)
    end

    it 'add(Years) handles leap-year clamping' do
      d = Use::Internal.build(2024, Calendar::Feb[], 29)
      expect(Use::Internal.shift(d, Calendar::Years[], 1))
        .to eql Use::Internal.build(2025, Calendar::Feb[], 28)
    end

    it 'diff(Days) counts whole days between dates' do
      a = Use::Internal.build(2026, Calendar::May[], 4)
      b = Use::Internal.build(2026, Calendar::May[], 14)
      expect(Use::Internal.span(a, b, Calendar::Days[])).to eql 10
    end

    it 'diff(Months) counts full months between dates' do
      a = Use::Internal.build(2026, Calendar::Jan[], 15)
      b = Use::Internal.build(2026, Calendar::Apr[], 14)
      expect(Use::Internal.span(a, b, Calendar::Months[])).to eql 2
    end

    context 'Encodable / Decodable' do
      let(:source) do
        <<~JADE
          module Json exposing (date_from_json, date_to_json)

          import Calendar exposing (Date, Month(..))
          import Encode
          import Decode exposing (DecodeError)


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
        d = Use::Internal.build(2026, Calendar::May[], 4)
        expect(Json::Internal.date_to_json(d)).to eql '"2026-05-04"'
      end

      it 'decodes a Date from an ISO 8601 string' do
        expect(Json::Internal.date_from_json('"2026-05-04"'))
          .to be_ok(have_attributes(year: 2026, day: 4))
      end

      it 'fails decoding an invalid ISO date' do
        expect(Json::Internal.date_from_json('"not-a-date"')).to be_err
      end
    end
  end
end
