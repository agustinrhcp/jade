require 'spec_helper'

require 'jade'
require 'jade/module_loader'

module Jade
  describe 'Clock' do
    include_context 'with test compiler'

    let(:source) do
      <<~JADE
        module Use exposing(now, build, millis, advance, span,
                            iso, parse_iso, to_date, before, equal)

        import Clock exposing(Instant, Duration)
        import Calendar exposing(Date, Month(..))

        def now() -> Task(Instant, Never)
          Clock.now
        end

        def build(n: Int) -> Instant
          Clock.from_millis(n)
        end

        def millis(i: Instant) -> Int
          Clock.to_millis(i)
        end

        def advance(i: Instant, d: Duration) -> Instant
          Clock.add(i, d)
        end

        def span(a: Instant, b: Instant) -> Duration
          Clock.diff(a, b)
        end

        def iso(i: Instant) -> String
          Clock.to_iso_string(i)
        end

        def parse_iso(s: String) -> Result(Instant, String)
          Clock.from_iso_string(s)
        end

        def to_date(i: Instant) -> Date
          Clock.to_date(i)
        end

        def before(a: Instant, b: Instant) -> Bool
          a < b
        end

        def equal(a: Instant, b: Instant) -> Bool
          a == b
        end
      JADE
    end

    before { test_compiler.require('use', source) }

    it 'now() returns a Task that resolves to an Instant' do
      result = Use.now.call.run
      expect(result).to be_a(Result::Ok)
      i = result._1
      expect(i.millis).to be_a(Integer)
      expect(i.millis).to be > 0
    end

    it 'builds and reads back epoch millis' do
      i = Use.build.call(1_700_000_000_000)
      expect(Use.millis.call(i)).to eql 1_700_000_000_000
    end

    it 'add(instant, duration) returns a shifted instant' do
      i = Use.build.call(1_000_000)
      d = ::Clock::Duration[500]
      expect(Use.advance.call(i, d).millis).to eql 1_000_500
    end

    it 'diff(a, b) returns a duration in millis' do
      a = Use.build.call(1_000_000)
      b = Use.build.call(1_000_500)
      expect(Use.span.call(a, b).millis).to eql 500
    end

    it 'formats an Instant as an ISO 8601 UTC string' do
      i = Use.build.call(0)
      expect(Use.iso.call(i)).to eql '1970-01-01T00:00:00Z'
    end

    it 'formats a known epoch into an ISO string' do
      i = Use.build.call(1_700_000_000_000)
      expect(Use.iso.call(i)).to eql '2023-11-14T22:13:20Z'
    end

    it 'parses an ISO 8601 UTC string' do
      result = Use.parse_iso.call('1970-01-01T00:00:00Z')
      expect(result).to be_a(Result::Ok)
      expect(result._1.millis).to eql 0
    end

    it 'parses with a space separator (PostgreSQL style)' do
      result = Use.parse_iso.call('2023-11-14 22:13:20Z')
      expect(result).to be_a(Result::Ok)
      expect(result._1.millis).to eql 1_700_000_000_000
    end

    it 'parses sub-second precision' do
      result = Use.parse_iso.call('2023-11-14T22:13:20.123Z')
      expect(result).to be_a(Result::Ok)
      expect(result._1.millis).to eql 1_700_000_000_123
    end

    it 'returns Err for an invalid timestamp' do
      expect(Use.parse_iso.call('not-a-time')).to be_a(Result::Err)
    end

    it 'round-trips via ISO' do
      i = Use.build.call(1_700_000_000_000)
      iso = Use.iso.call(i)
      result = Use.parse_iso.call(iso)
      expect(result).to be_a(Result::Ok)
      expect(result._1.millis).to eql 1_700_000_000_000
    end

    it 'projects an Instant onto a Calendar Date' do
      i = Use.build.call(1_700_000_000_000)
      d = Use.to_date.call(i)
      expect(d.year).to eql 2023
      expect(d.month).to eql ::Calendar::Nov[]
      expect(d.day).to eql 14
    end

    it 'orders instants via Comparable' do
      a = Use.build.call(100)
      b = Use.build.call(200)
      expect(Use.before.call(a, b)).to be true
      expect(Use.before.call(b, a)).to be false
    end

    it 'compares instants via Eq' do
      a = Use.build.call(100)
      b = Use.build.call(100)
      c = Use.build.call(101)
      expect(Use.equal.call(a, b)).to be true
      expect(Use.equal.call(a, c)).to be false
    end
  end
end
