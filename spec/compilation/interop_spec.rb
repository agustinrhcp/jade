require 'spec_helper'

require 'jade'
require 'jade/module_loader'

module Jade
  describe 'Interop' do
    include_context 'with test compiler'

    module TestDate
      extend self

      require 'date'

      TODAY = ::Date.new(2026, 1, 31).freeze

      def internal_today
        to_i(TODAY)
      end

      def internal_today_plus_n_days(n)
        (TODAY + n).then { to_i(it) }
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
          internal_today: Int,
          internal_today_plus_n_days: Int -> Int

        def today() -> Int
          internal_today()
        end

        def today_plus_n_days(n: Int) -> Int
          internal_today_plus_n_days(n)
        end
      JADE
    end

    it 'returns an Int' do
      test_compiler.require('with_interop', with_interop_source)
      expect(WithInterop.today.call()).to eql(20260131)
      expect(WithInterop.today_plus_n_days.call(1)).to eql(20260201)
    end

    context 'more elaborate date' do
      module TestBetterDate
        extend self

        require 'date'

        TODAY = ::Date.new(2026, 1, 31).freeze

        def internal_today
          { year: TODAY.year, month: TODAY.month, day: TODAY.day }
        end
      end

      let(:with_interop_source) do
        <<~JADE
          module WithInterop exposing(today)

          uses Jade::TestBetterDate with
            internal_today: { year: Int, month: Int, day: Int }

          def today() -> { year: Int, month: Int, day: Int }
            internal_today()
          end
        JADE
      end

      it 'returns an Int' do
        test_compiler.require('with_interop', with_interop_source)
        date = WithInterop.today.call()
        expect(date.year).to eql 2026
        expect(date.month).to eql 1
        expect(date.day).to eql 31
      end

      context 'when expecting a type variable' do
        let(:with_interop_source) do
          <<~JADE
            module WithInterop exposing(today)

            uses Jade::TestBetterDate with
              internal_today: a

            def today() -> a
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
              internal_today: Date

            def today() -> Date
              internal_today()
            end
          JADE
        end

        it 'fails' do
          expect { test_compiler.require('with_interop', with_interop_source) }
            .to raise_error(RuntimeError, /Union \(Date\) cannot be lowered for interop/)
        end
      end

      context 'when expecting a Maybe constructor' do
        let(:with_interop_source) do
          <<~JADE
            module WithInterop exposing(today)

            uses Jade::TestBetterDate with
              internal_today: Maybe({ year: Int, month: Int, day: Int })

            def today() -> Maybe({ year: Int, month: Int, day: Int })
              internal_today()
            end
          JADE
        end

        it 'fails' do
          test_compiler.require('with_interop', with_interop_source)
          expect(WithInterop.today.call()).to be_a(Maybe::Just)
        end
      end
    end

    context 'stdlib date' do
      module Stdlib
        require 'date'

        module Date
          extend self

          TODAY = ::Date.new(2026, 2, 5).freeze

          def today_
            { year: TODAY.year, month: TODAY.month, day: TODAY.day }
          end
        end
      end

      let(:stdlib_date) do
        <<~JADE
          module StdlibDate exposing (Date, today, year)

          type Date = Date({ year: Int, month: Int, day: Int })

          type Unit = Years | Months | Days

          uses Jade::Stdlib::Date with
            today_: { year: Int, month: Int, day: Int }

          def today() -> Date
            today_() |> Date
          end

          def year(date: Date) -> Int
            case date
            of Date(record) then
              record.year
            end
          end
        JADE
      end

      it 'returns an Int' do
        test_compiler.require('stdlib_date', stdlib_date)
        date = StdlibDate.today.call()
        expect(StdlibDate.year.call(date)).to eql 2026
      end
    end
  end
end
