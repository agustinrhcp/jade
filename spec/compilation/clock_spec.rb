require 'spec_helper'

require 'jade'
require 'jade/module_loader'

module Jade
  describe 'Clock' do
    include_context 'with test compiler'

    let(:source) do
      <<~JADE
        module Use exposing (
          advance,
          at_ms,
          before,
          day_to,
          epoch,
          equal,
          hr_to,
          iso,
          min_to,
          ms_to,
          now,
          parse_iso,
          parts,
          sec_to,
          since_epoch_ms,
          span,
          time_of_day,
          to_date,
          to_day,
          to_hr,
          to_min,
          to_ms,
          to_sec,
        )

        import Clock exposing (Duration, Instant)
        import Calendar exposing (Date, Month(..))


        def now -> Task(Instant, Never)
          Clock.now


        def epoch -> Instant
          Clock.epoch


        def at_ms(n: Int) -> Instant
          Clock.add(Clock.epoch, Clock.millis(n))


        def since_epoch_ms(i: Instant) -> Int
          Clock.diff(Clock.epoch, i) |> Clock.in_millis


        def ms_to(n: Int) -> Duration
          Clock.millis(n)


        def to_ms(d: Duration) -> Int
          Clock.in_millis(d)


        def sec_to(n: Int) -> Duration
          Clock.seconds(n)


        def to_sec(d: Duration) -> Int
          Clock.in_seconds(d)


        def min_to(n: Int) -> Duration
          Clock.minutes(n)


        def to_min(d: Duration) -> Int
          Clock.in_minutes(d)


        def hr_to(n: Int) -> Duration
          Clock.hours(n)


        def to_hr(d: Duration) -> Int
          Clock.in_hours(d)


        def day_to(n: Int) -> Duration
          Clock.days(n)


        def to_day(d: Duration) -> Int
          Clock.in_days(d)


        def parts(d: Duration) -> {
          days: Int,
          hours: Int,
          minutes: Int,
          seconds: Int,
          millis: Int,
        }
          Clock.parts(d)


        def time_of_day(i: Instant) -> {
          hour: Int,
          minute: Int,
          second: Int,
          millisecond: Int,
        }
          Clock.at_time(i)


        def advance(i: Instant, d: Duration) -> Instant
          Clock.add(i, d)


        def span(a: Instant, b: Instant) -> Duration
          Clock.diff(a, b)


        def iso(i: Instant) -> String
          Clock.to_iso(i)


        def parse_iso(s: String) -> Result(Instant, String)
          Clock.from_iso(s)


        def to_date(i: Instant) -> Date
          Clock.on_date(i)


        def before(a: Instant, b: Instant) -> Bool
          a < b


        def equal(a: Instant, b: Instant) -> Bool
          a == b
      JADE
    end

    def duration(n) = Clock::Duration[n]

    before { test_compiler.require('use', source) }

    it 'now() returns a Task that resolves to an Instant after the epoch' do
      result = Use::Internal.now.call.run
      expect(result).to be_ok
      expect(Use::Internal.since_epoch_ms.call(result._1)).to be > 0
    end

    it 'epoch is 1970-01-01T00:00:00Z' do
      expect(Use::Internal.iso.call(Use::Internal.epoch.call)).to eql '1970-01-01T00:00:00Z'
    end

    it 'add(epoch, from_millis(n)) reaches a specific Instant' do
      i = Use::Internal.at_ms.call(1_700_000_000_000)
      expect(Use::Internal.since_epoch_ms.call(i)).to eql 1_700_000_000_000
    end

    describe 'Duration unit constructors and accessors' do
      it 'from_millis / to_millis round-trip' do
        expect(Use::Internal.to_ms.call(Use::Internal.ms_to.call(500))).to eql 500
      end

      it 'from_seconds / to_seconds' do
        expect(Use::Internal.to_ms.call(Use::Internal.sec_to.call(60))).to eql 60_000
        expect(Use::Internal.to_sec.call(Use::Internal.ms_to.call(2_500))).to eql 2
      end

      it 'from_minutes / to_minutes' do
        expect(Use::Internal.to_ms.call(Use::Internal.min_to.call(2))).to eql 120_000
        expect(Use::Internal.to_min.call(Use::Internal.ms_to.call(120_500))).to eql 2
      end

      it 'from_hours / to_hours' do
        expect(Use::Internal.to_ms.call(Use::Internal.hr_to.call(1))).to eql 3_600_000
        expect(Use::Internal.to_hr.call(Use::Internal.ms_to.call(7_260_000))).to eql 2
      end

      it 'from_days / to_days' do
        expect(Use::Internal.to_ms.call(Use::Internal.day_to.call(1))).to eql 86_400_000
        expect(Use::Internal.to_day.call(Use::Internal.ms_to.call(2 * 86_400_000 + 100))).to eql 2
      end
    end

    describe 'to_parts on a Duration' do
      it 'breaks a complex duration into named components' do
        d = duration(1 * 86_400_000 + 2 * 3_600_000 + 3 * 60_000 + 4 * 1_000 + 5)
        parts = Use::Internal.parts.call(d)
        expect(parts.days).to    eql 1
        expect(parts.hours).to   eql 2
        expect(parts.minutes).to eql 3
        expect(parts.seconds).to eql 4
        expect(parts.millis).to  eql 5
      end

      it 'zeros out parts smaller than the duration' do
        parts = Use::Internal.parts.call(duration(500))
        expect(parts.days).to    eql 0
        expect(parts.hours).to   eql 0
        expect(parts.minutes).to eql 0
        expect(parts.seconds).to eql 0
        expect(parts.millis).to  eql 500
      end
    end

    describe 'to_time_of_day on an Instant' do
      it 'extracts wall-clock parts from epoch millis' do
        tod = Use::Internal.time_of_day.call(Use::Internal.at_ms.call(1_700_000_000_123))
        expect(tod.hour).to        eql 22
        expect(tod.minute).to      eql 13
        expect(tod.second).to      eql 20
        expect(tod.millisecond).to eql 123
      end

      it 'returns midnight for the epoch' do
        tod = Use::Internal.time_of_day.call(Use::Internal.epoch.call)
        expect(tod.hour).to        eql 0
        expect(tod.minute).to      eql 0
        expect(tod.second).to      eql 0
        expect(tod.millisecond).to eql 0
      end
    end

    describe 'add / diff' do
      it 'add(instant, duration) returns a shifted instant' do
        i = Use::Internal.at_ms.call(1_000_000)
        d = duration(500)
        expect(Use::Internal.since_epoch_ms.call(Use::Internal.advance.call(i, d))).to eql 1_000_500
      end

      it 'diff(a, b) returns a Duration in millis' do
        a = Use::Internal.at_ms.call(1_000_000)
        b = Use::Internal.at_ms.call(1_000_500)
        expect(Use::Internal.to_ms.call(Use::Internal.span.call(a, b))).to eql 500
      end
    end

    describe 'ISO 8601 formatting and parsing' do
      it 'formats a known epoch into an ISO string' do
        expect(Use::Internal.iso.call(Use::Internal.at_ms.call(1_700_000_000_000))).to eql '2023-11-14T22:13:20Z'
      end

      it 'parses an ISO 8601 UTC string' do
        result = Use::Internal.parse_iso.call('1970-01-01T00:00:00Z')
        expect(result).to be_ok
        expect(Use::Internal.since_epoch_ms.call(result._1)).to eql 0
      end

      it 'parses with a space separator (PostgreSQL style)' do
        result = Use::Internal.parse_iso.call('2023-11-14 22:13:20Z')
        expect(result).to be_ok
        expect(Use::Internal.since_epoch_ms.call(result._1)).to eql 1_700_000_000_000
      end

      it 'parses sub-second precision' do
        result = Use::Internal.parse_iso.call('2023-11-14T22:13:20.123Z')
        expect(result).to be_ok
        expect(Use::Internal.since_epoch_ms.call(result._1)).to eql 1_700_000_000_123
      end

      it 'parses zero-padded hour/minute/second fields' do
        result = Use::Internal.parse_iso.call('2026-05-22T09:08:07Z')
        expect(result).to be_ok
      end

      it 'returns Err for an invalid timestamp' do
        expect(Use::Internal.parse_iso.call('not-a-time')).to be_err
      end

      it 'projects an Instant onto a Calendar Date' do
        d = Use::Internal.to_date.call(Use::Internal.at_ms.call(1_700_000_000_000))
        expect(d).to have_attributes(year: 2023, day: 14)
        expect(d.month).to be_nov
      end
    end

    describe 'Comparable / Eq on Instant' do
      it 'orders instants' do
        a = Use::Internal.at_ms.call(100)
        b = Use::Internal.at_ms.call(200)
        expect(Use::Internal.before.call(a, b)).to be true
        expect(Use::Internal.before.call(b, a)).to be false
      end

      it 'compares for equality' do
        a = Use::Internal.at_ms.call(100)
        b = Use::Internal.at_ms.call(100)
        c = Use::Internal.at_ms.call(101)
        expect(Use::Internal.equal.call(a, b)).to be true
        expect(Use::Internal.equal.call(a, c)).to be false
      end
    end

    describe 'Encodable / Decodable' do
      let(:source) do
        <<~JADE
          module Json exposing (
            duration_from_json,
            duration_to_json,
            instant_from_json,
            instant_to_json,
            make_duration,
          )

          import Clock exposing (Duration, Instant)
          import Encode
          import Decode exposing (DecodeError)


          def make_duration(ms: Int) -> Duration
            Clock.millis(ms)


          def instant_to_json(i: Instant) -> String
            Encode.encode_to_string(Encode.encode(i))


          def instant_from_json(s: String) -> Result(Instant, DecodeError)
            Decode.from_json(s)


          def duration_to_json(d: Duration) -> String
            Encode.encode_to_string(Encode.encode(d))


          def duration_from_json(s: String) -> Result(Duration, DecodeError)
            Decode.from_json(s)
        JADE
      end

      before { test_compiler.require('json', source) }

      it 'encodes an Instant as ISO 8601' do
        i = Use::Internal.at_ms.call(1_700_000_000_000)
        expect(Json::Internal.instant_to_json.call(i)).to eql '"2023-11-14T22:13:20Z"'
      end

      it 'decodes an Instant from ISO 8601' do
        result = Json::Internal.instant_from_json.call('"2023-11-14T22:13:20Z"')
        expect(result).to be_ok
        expect(Use::Internal.since_epoch_ms.call(result._1)).to eql 1_700_000_000_000
      end

      it 'fails decoding an invalid Instant' do
        expect(Json::Internal.instant_from_json.call('"nope"')).to be_err
      end

      it 'encodes a Duration as Int milliseconds' do
        d = Json::Internal.make_duration.call(5000)
        expect(Json::Internal.duration_to_json.call(d)).to eql '5000'
      end

      it 'decodes a Duration from Int milliseconds' do
        result = Json::Internal.duration_from_json.call('5000')
        expect(result).to be_ok
        expect(result._1).to eql Json::Internal.make_duration.call(5000)
      end
    end
  end
end
