require 'spec_helper'

require 'jade'
require 'jade/task'
require 'jade/module_loader'

module Jade
  describe 'Interop' do
    include_context 'with test compiler'

    module TestDate
      extend self

      require 'date'

      TODAY = ::Date.new(2026, 1, 31).freeze

      def internal_today
        Jade::Task.ok { to_i(TODAY) }
      end

      def internal_today_plus_n_days(n)
        Jade::Task.ok { (TODAY + n).then { to_i(it) } }
      end

      private

      def to_i(date)
        string_date = date.year.to_s +
          date.month.to_s.rjust(2, '0') +
          date.day.to_s.rjust(2, '0')

        string_date.to_i
      end
    end

    let(:with_interop_source) do
      <<~JADE
        module WithInterop exposing(today)

        uses Jade::TestDate with
          internal_today: Task(Int, Never),
          internal_today_plus_n_days: Int -> Task(Int, Never)
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
      expect(WithInterop.today.call().run).to eql(Result::Ok[20260131])
      expect(WithInterop.today_plus_n_days.call(1).run).to eql(Result::Ok[20260201])
    end

    context 'more elaborate date' do
      module TestBetterDate
        extend self

        require 'date'

        TODAY = ::Date.new(2026, 1, 31).freeze

        def internal_today
          Jade::Task.ok { { year: TODAY.year, month: TODAY.month, day: TODAY.day } }
        end
      end

      let(:with_interop_source) do
        <<~JADE
          module WithInterop exposing(today)

          uses Jade::TestBetterDate with
            internal_today: Task({ year: Int, month: Int, day: Int }, Never)
          end

          def today() -> Task({ year: Int, month: Int, day: Int }, Never)
            internal_today()
          end
        JADE
      end

      it 'returns a record wrapped in Task' do
        test_compiler.require('with_interop', with_interop_source)
        result = WithInterop.today.call().run
        expect(result).to be_a(Result::Ok)
        date = result._1
        expect(date.year).to eql 2026
        expect(date.month).to eql 1
        expect(date.day).to eql 31
      end

      context 'when expecting a type variable' do
        let(:with_interop_source) do
          <<~JADE
            module WithInterop exposing(today)

            uses Jade::TestBetterDate with
              internal_today: Task(a, Never)
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

      context 'when expecting a non literal constructor' do
        let(:with_interop_source) do
          <<~JADE
            module WithInterop exposing(today)

            type Date = Date(Int, Int, Int)

            uses Jade::TestBetterDate with
              internal_today: Task(Date, Never)
            end

            def today() -> Task(Date, Never)
              internal_today()
            end
          JADE
        end

        it 'fails' do
          expect { test_compiler.require('with_interop', with_interop_source) }
            .to raise_error(RuntimeError, /Union \(Date\) cannot be lowered for interop/)
        end
      end

      context 'when expecting a Maybe value' do
        module TestMaybeDate
          extend self

          require 'date'

          TODAY = ::Date.new(2026, 1, 31).freeze

          def internal_today
            Jade::Task.ok { { year: TODAY.year, month: TODAY.month, day: TODAY.day } }
          end
        end

        let(:with_interop_source) do
          <<~JADE
            module WithInterop exposing(today)

            uses Jade::TestMaybeDate with
              internal_today: Task(Maybe({ year: Int, month: Int, day: Int }), Never)
            end

            def today() -> Task(Maybe({ year: Int, month: Int, day: Int }), Never)
              internal_today()
            end
          JADE
        end

        it 'returns a Just wrapped in Task' do
          test_compiler.require('with_interop', with_interop_source)
          result = WithInterop.today.call().run
          expect(result).to be_a(Result::Ok)
          expect(result._1).to be_a(Maybe::Just)
        end
      end

      context 'when a port does not return Task' do
        let(:with_interop_source) do
          <<~JADE
            module WithInterop exposing(today)

            uses Jade::TestBetterDate with
              internal_today: { year: Int, month: Int, day: Int }
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
    end

    context 'task that errors' do
      module TestFallible
        extend self

        def fetch_data
          Jade::Task.error { "not found" }
        end
      end

      let(:with_interop_source) do
        <<~JADE
          module WithInterop exposing(fetch)

          uses Jade::TestFallible with
            fetch_data: Task(Int, String)
          end

          def fetch() -> Task(Int, String)
            fetch_data()
          end
        JADE
      end

      it 'returns an Err wrapped in Task' do
        test_compiler.require('with_interop', with_interop_source)
        expect(WithInterop.fetch.call().run).to eql(Result::Err["not found"])
      end
    end

    context 'task where the port returns a non-Task value' do
      module TestBadPort
        extend self

        def fetch_number
          42
        end
      end

      let(:with_interop_source) do
        <<~JADE
          module WithInterop exposing(fetch)

          uses Jade::TestBadPort with
            fetch_number: Task(Int, Never)
          end

          def fetch() -> Task(Int, Never)
            fetch_number()
          end
        JADE
      end

      it 'raises a guard error immediately when called' do
        test_compiler.require('with_interop', with_interop_source)
        expect { WithInterop.fetch.call() }
          .to raise_error(Jade::Interop::Guard::Error, /Expected Jade::Task/)
      end
    end

    context 'task where the inner value does not match the declared type' do
      module TestWrongInner
        extend self

        def fetch_number
          Jade::Task.ok { "oops, a string" }
        end
      end

      let(:with_interop_source) do
        <<~JADE
          module WithInterop exposing(fetch)

          uses Jade::TestWrongInner with
            fetch_number: Task(Int, Never)
          end

          def fetch() -> Task(Int, Never)
            fetch_number()
          end
        JADE
      end

      it 'raises a guard error lazily when run' do
        test_compiler.require('with_interop', with_interop_source)
        task = WithInterop.fetch.call()
        expect { task.run }
          .to raise_error(Jade::Interop::Guard::Error, /Expected Integer/)
      end
    end

    context 'chaining port tasks with <-' do
      module TestArithmetic
        extend self

        def get_one = Jade::Task.ok { 1 }
        def get_two = Jade::Task.ok { 2 }
        def get_error = Jade::Task.error { "port failed" }
      end

      let(:with_interop_source) do
        <<~JADE
          module WithInterop exposing(sum, short_circuits)

          uses Jade::TestArithmetic with
            get_one: Task(Int, String),
            get_two: Task(Int, String),
            get_error: Task(Int, String)
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
        expect(WithInterop.sum.call().run).to eql(Result::Ok[3])
      end

      it 'short-circuits when a port task fails' do
        expect(WithInterop.short_circuits.call().run).to eql(Result::Err["port failed"])
      end

      it 'is lazy — no Ruby code runs until .run' do
        task = WithInterop.sum.call()
        expect(task).to be_a(Jade::Task)
      end
    end

    context 'stdlib date' do
      module Stdlib
        require 'date'

        module Date
          extend self

          TODAY = ::Date.new(2026, 2, 5).freeze

          def today_
            Jade::Task.ok { { year: TODAY.year, month: TODAY.month, day: TODAY.day } }
          end
        end
      end

      let(:stdlib_date) do
        <<~JADE
          module StdlibDate exposing (today, year)

          uses Jade::Stdlib::Date with
            today_: Task({ year: Int, month: Int, day: Int }, Never)
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
        expect(result).to be_a(Result::Ok)
        expect(StdlibDate.year.call(result._1)).to eql 2026
      end
    end
  end
end
