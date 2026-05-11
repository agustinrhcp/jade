require 'spec_helper'

require 'jade'
require 'jade/module_loader'

module Jade
  describe 'Interop' do
    include_context 'with test compiler'

    module TestDate
      extend Jade::Port

      require 'date'

      TODAY = ::Date.new(2026, 1, 31).freeze

      def self.to_i(date)
        (date.year.to_s +
          date.month.to_s.rjust(2, '0') +
          date.day.to_s.rjust(2, '0')).to_i
      end

      task :internal_today do |t|
        t.ok(to_i(TODAY))
      end

      task :internal_today_plus_n_days do |t, n|
        t.ok(to_i(TODAY + n))
      end
    end

    let(:with_interop_source) do
      <<~JADE
        module WithInterop exposing (today)

        uses Jade::TestDate with
          internal_today : Task(Int, Never),
          internal_today_plus_n_days : Int -> Task(Int, Never)
        end

        def today() -> Task(Int, Never)
          internal_today()
        end

        def today_plus_n_days(n: Int) -> Task(Int, Never)
          internal_today_plus_n_days(n)
        end
      JADE
    end

    it 'returns an Int wrapped in Task' do
      test_compiler.require('with_interop', with_interop_source)
      expect(WithInterop.today.call().run).to be_ok(20260131)
      expect(WithInterop.today_plus_n_days.call(1).run).to be_ok(20260201)
    end

    context 'more elaborate date' do
      module TestBetterDate
        extend Jade::Port

        require 'date'

        TODAY = ::Date.new(2026, 1, 31).freeze

        task :internal_today do |t|
          t.ok({ year: TODAY.year, month: TODAY.month, day: TODAY.day })
        end
      end

      let(:with_interop_source) do
        <<~JADE
          module WithInterop exposing (today)

          uses Jade::TestBetterDate with
            internal_today : Task({ year: Int, month: Int, day: Int }, Never)
          end

          def today() -> Task({ year: Int, month: Int, day: Int }, Never)
            internal_today()
          end
        JADE
      end

      it 'returns a record wrapped in Task' do
        test_compiler.require('with_interop', with_interop_source)

        expect(WithInterop.today.call().run)
          .to be_ok(have_attributes(year: 2026, month: 1, day: 31))
      end

      context 'when expecting a type variable' do
        let(:with_interop_source) do
          <<~JADE
            module WithInterop exposing (today)

            uses Jade::TestBetterDate with
              internal_today : Task(a, Never)
            end

            def today() -> Task(a, Never)
              internal_today()
            end
          JADE
        end

        it 'fails' do
          expect { test_compiler.require('with_interop', with_interop_source) }
            .to raise_error(RuntimeError, /Type param \(a\) cannot be lowered for interop/)
        end
      end

      context 'when expecting a named struct' do
        module TestStructDate
          extend Jade::Port

          require 'date'

          TODAY = ::Date.new(2026, 1, 31).freeze

          task :internal_today do |t|
            t.ok({ year: TODAY.year, month: TODAY.month, day: TODAY.day })
          end
        end

        let(:with_interop_source) do
          <<~JADE
            module WithInterop exposing (today)

            struct Date = {
              year: Int,
              month: Int,
              day: Int
            }

            uses Jade::TestStructDate with
              internal_today : Task(Date, Never)
            end

            def today() -> Task(Date, Never)
              internal_today()
            end
          JADE
        end

        it 'coerces the hash into a struct' do
          test_compiler.require('with_interop', with_interop_source)

          expect(WithInterop.today.call().run)
            .to be_ok(have_attributes(year: 2026, month: 1, day: 31))
        end
      end

      context 'when expecting a non literal constructor' do
        let(:with_interop_source) do
          <<~JADE
            module WithInterop exposing (today)

            type Date = Date(Int, Int, Int)

            uses Jade::TestBetterDate with
              internal_today : Task(Date, Never)
            end

            def today() -> Task(Date, Never)
              internal_today()
            end
          JADE
        end

        it 'fails — Decodable cannot be derived and the user did not implement it' do
          expect { test_compiler.require('with_interop', with_interop_source) }
            .to raise_error(RuntimeError, /Port `internal_today` cannot decode its ok arm \(`Date`\): no Decodable instance/)
        end
      end

      context 'when expecting a Maybe value' do
        module TestMaybeDate
          extend Jade::Port

          require 'date'

          TODAY = ::Date.new(2026, 1, 31).freeze

          task :internal_today do |t|
            t.ok({ year: TODAY.year, month: TODAY.month, day: TODAY.day })
          end
        end

        let(:with_interop_source) do
          <<~JADE
            module WithInterop exposing (today)

            uses Jade::TestMaybeDate with
              internal_today : Task(Maybe({ year: Int, month: Int, day: Int }), Never)
            end

            def today() -> Task(Maybe({ year: Int, month: Int, day: Int }), Never)
              internal_today()
            end
          JADE
        end

        it 'returns a Just wrapped in Task' do
          test_compiler.require('with_interop', with_interop_source)

          expect(WithInterop.today.call().run).to be_ok(look_like(:Just, anything))
        end
      end

      context 'when a port does not return Task' do
        let(:with_interop_source) do
          <<~JADE
            module WithInterop exposing (today)

            uses Jade::TestBetterDate with
              internal_today : { year: Int, month: Int, day: Int }
            end

            def today() -> { year: Int, month: Int, day: Int }
              internal_today()
            end
          JADE
        end

        it 'fails with NonTaskPort error' do
          expect { test_compiler.require('with_interop', with_interop_source) }
            .to raise_error(RuntimeError, /Port `internal_today` must return a Task type/)
        end
      end

      context 'when a port declares a Task whose Ok arm is itself a Task' do
        let(:with_interop_source) do
          <<~JADE
            module WithInterop exposing (today)

            uses Jade::TestBetterDate with
              internal_today : Task(Task(Int, Never), Never)
            end

            def today() -> Task(Task(Int, Never), Never)
              internal_today()
            end
          JADE
        end

        it 'fails with NestedTaskPort error' do
          expect { test_compiler.require('with_interop', with_interop_source) }
            .to raise_error(RuntimeError, /tasks must not return tasks/)
        end
      end
    end

    context 'task that errors' do
      module TestFallible
        extend Jade::Port

        task :fetch_data do |t|
          t.err("not found")
        end
      end

      let(:with_interop_source) do
        <<~JADE
          module WithInterop exposing (fetch)

          uses Jade::TestFallible with
            fetch_data : Task(Int, String)
          end

          def fetch() -> Task(Int, String)
            fetch_data()
          end
        JADE
      end

      it 'returns an Err wrapped in Task' do
        test_compiler.require('with_interop', with_interop_source)
        expect(WithInterop.fetch.call().run).to be_err("not found")
      end
    end

    context 'task where the port is not registered as a Task' do
      module TestBadPort
        extend self

        def fetch_number
          42
        end
      end

      let(:with_interop_source) do
        <<~JADE
          module WithInterop exposing (fetch)

          uses Jade::TestBadPort with
            fetch_number : Task(Int, Never)
          end

          def fetch() -> Task(Int, Never)
            fetch_number()
          end
        JADE
      end

      it 'raises immediately when called' do
        test_compiler.require('with_interop', with_interop_source)
        expect { WithInterop.fetch.call() }
          .to raise_error(Jade::Interop::PortNotRegistered, /not a Jade port/)
      end
    end

    context 'task where the inner value does not match the declared type' do
      module TestWrongInner
        extend Jade::Port

        task :fetch_number do |t|
          t.ok("oops, a string")
        end
      end

      let(:with_interop_source) do
        <<~JADE
          module WithInterop exposing (fetch)

          uses Jade::TestWrongInner with
            fetch_number : Task(Int, Never)
          end

          def fetch() -> Task(Int, Never)
            fetch_number()
          end
        JADE
      end

      it 'raises a decode error lazily when run' do
        test_compiler.require('with_interop', with_interop_source)
        task = WithInterop.fetch.call()
        expect { task.run }
          .to raise_error(Jade::Interop::DecodeError, /expected Int, got String/)
      end
    end

    context 'chaining port tasks with <-' do
      module TestArithmetic
        extend Jade::Port

        task(:get_one)   { |t| t.ok(1) }
        task(:get_two)   { |t| t.ok(2) }
        task(:get_error) { |t| t.err("port failed") }
      end

      let(:with_interop_source) do
        <<~JADE
          module WithInterop exposing (short_circuits, sum)

          uses Jade::TestArithmetic with
            get_one : Task(Int, String),
            get_two : Task(Int, String),
            get_error : Task(Int, String)
          end

          def sum() -> Task(Int, String)
            one <- get_one()
            two <- get_two()

            Task.succeed(one + two)
          end

          def short_circuits() -> Task(Int, String)
            one <- get_error()
            two <- get_two()

            Task.succeed(one + two)
          end
        JADE
      end

      before { test_compiler.require('with_interop', with_interop_source) }

      it 'chains port tasks and returns the combined result' do
        expect(WithInterop.sum.call().run).to be_ok(3)
      end

      it 'short-circuits when a port task fails' do
        expect(WithInterop.short_circuits.call().run).to be_err("port failed")
      end

      it 'is lazy — no Ruby code runs until .run' do
        task = WithInterop.sum.call()
        expect(task).to be_a(Jade::Task)
      end
    end

    context 'a port using Decode.Value opts out of decoding' do
      module TestPassThrough
        extend Jade::Port

        task :fetch_anything do |t|
          t.ok({ totally: 'arbitrary', nested: { stuff: [1, 2, 3] } })
        end
      end

      let(:with_interop_source) do
        <<~JADE
          module WithInterop exposing (fetch)

          import Decode exposing (Value)

          uses Jade::TestPassThrough with
            fetch_anything : Task(Value, Never)
          end

          def fetch() -> Task(Value, Never)
            fetch_anything()
          end
        JADE
      end

      it 'passes the raw Ruby value through unchanged' do
        test_compiler.require('with_interop', with_interop_source)
        result = WithInterop.fetch.call().run
        expect(result).to be_ok
        expect(result._1).to eql({ totally: 'arbitrary', nested: { stuff: [1, 2, 3] } })
      end
    end

    context 'a named struct produces an instance of the struct class' do
      module TestNamedStruct
        extend Jade::Port

        task :fetch_user do |t|
          t.ok({ name: 'Ada', age: 36 })
        end
      end

      let(:with_interop_source) do
        <<~JADE
          module WithInterop exposing (fetch)

          struct User = {
            name: String,
            age: Int
          }

          uses Jade::TestNamedStruct with
            fetch_user : Task(User, Never)
          end

          def fetch() -> Task(User, Never)
            fetch_user()
          end
        JADE
      end

      it 'returns the struct as the named class' do
        test_compiler.require('with_interop', with_interop_source)
        result = WithInterop.fetch.call().run
        expect(result).to be_ok
        expect(result._1).to be_a(WithInterop::User)
        expect(result._1.name).to eql 'Ada'
        expect(result._1.age).to eql 36
      end
    end

    context 'a port with a missing field surfaces the path' do
      module TestMissingField
        extend Jade::Port

        task :fetch_user do |t|
          t.ok({ name: 'Ada' })
        end
      end

      let(:with_interop_source) do
        <<~JADE
          module WithInterop exposing (fetch)

          struct User = {
            name: String,
            age: Int
          }

          uses Jade::TestMissingField with
            fetch_user : Task(User, Never)
          end

          def fetch() -> Task(User, Never)
            fetch_user()
          end
        JADE
      end

      it 'raises with a path-aware message' do
        test_compiler.require('with_interop', with_interop_source)
        expect { WithInterop.fetch.call().run }
          .to raise_error(Jade::Interop::DecodeError, /missing field `age`/)
      end
    end

    context 'a port with a union type uses the user-implemented Decodable' do
      module TestUnionPort
        extend Jade::Port

        task(:fetch_active)   { |t| t.ok('active') }
        task(:fetch_inactive) { |t| t.ok('inactive') }
        task(:fetch_bogus)    { |t| t.ok('weird') }
      end

      let(:with_interop_source) do
        <<~JADE
          module WithInterop exposing (active, bogus, inactive)

          import Decode exposing (Decodable, Decoder)

          type Status
            = Active
            | Inactive

          def status_decoder() -> Decoder(Status)
            Decode.and_then(
              Decode.string,
              (s) -> {
                case s
                of "active" then Decode.succeed(Active)
                of "inactive" then Decode.succeed(Inactive)
                of _ then Decode.fail("unknown status: " ++ s)
                end
              },
            )
          end

          implements Decodable(Status) with
            decoder: status_decoder
          end

          uses Jade::TestUnionPort with
            fetch_active : Task(Status, Never),
            fetch_inactive : Task(Status, Never),
            fetch_bogus : Task(Status, Never)
          end

          def active() -> Task(Status, Never)
            fetch_active()
          end

          def inactive() -> Task(Status, Never)
            fetch_inactive()
          end

          def bogus() -> Task(Status, Never)
            fetch_bogus()
          end
        JADE
      end

      before { test_compiler.require('with_interop', with_interop_source) }

      it 'decodes the active variant' do
        result = WithInterop.active.call().run
        expect(result).to be_ok
        expect(result._1).to look_like(:Active)
      end

      it 'decodes the inactive variant' do
        result = WithInterop.inactive.call().run
        expect(result).to be_ok
        expect(result._1).to look_like(:Inactive)
      end

      it 'raises when the decoder rejects the value' do
        expect { WithInterop.bogus.call().run }
          .to raise_error(Jade::Interop::DecodeError, /unknown status: weird/)
      end
    end

    context 'stdlib date' do
      module Stdlib
        require 'date'

        module Date
          extend Jade::Port

          TODAY = ::Date.new(2026, 2, 5).freeze

          task :today_ do |t|
            t.ok({ year: TODAY.year, month: TODAY.month, day: TODAY.day })
          end
        end
      end

      let(:stdlib_date) do
        <<~JADE
          module StdlibDate exposing (today, year)

          uses Jade::Stdlib::Date with
            today_ : Task({ year: Int, month: Int, day: Int }, Never)
          end

          def today() -> Task({ year: Int, month: Int, day: Int }, Never)
            today_()
          end

          def year(date: { year: Int, month: Int, day: Int }) -> Int
            date.year
          end
        JADE
      end

      it 'returns a Task with the date' do
        test_compiler.require('stdlib_date', stdlib_date)
        result = StdlibDate.today.call().run
        expect(result).to be_ok
        expect(StdlibDate.year.call(result._1)).to eql 2026
      end
    end
  end
end
