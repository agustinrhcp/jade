require 'spec_helper'

require 'stringio'

require 'jade/testing/runner'
require 'jade/testing/reporter'

module Jade
  module Testing
    describe Reporter do
      let(:io) { StringIO.new }

      Reason = Data.define(:description, :actual, :expected)

      def report(results, broken = [], format: :doc)
        Reporter.new(io:, color: false, format:).report(results, broken, Timing[1.5, 0.25])
        io.string
      end

      def reason(description = 'values to be equal', actual = '1', expected = '2')
        Reason[description, actual, expected]
      end

      it 'prints each group once, however many tests hang off it' do
        output = report([
          Passed[%w[MathTest Math adds]],
          Passed[%w[MathTest Math subtracts]],
        ])

        expect(output).to start_with <<~TXT
          MathTest
            Math
              . adds
              . subtracts
        TXT
      end

      it 'reprints a repeated name under a different parent' do
        output = report([
          Passed[%w[T outer inner a]],
          Passed[%w[T other inner b]],
        ])

        expect(output.scan(/inner/).size).to eql 2
      end

      it 'shows every reason a test failed for' do
        output = report([Failed[%w[T fails], [reason, reason('value to be True', 'False', 'True')]]])

        expect(output).to include [
          '    expected values to be equal',
          '',
          '      actual:   1',
          '      expected: 2',
          '',
          '    expected value to be True',
          '',
          '      actual:   False',
          '      expected: True',
        ].join("\n")
      end

      it 'drops the runner from a crash backtrace' do
        error = RuntimeError.new('boom')
        error.set_backtrace(["#{Reporter::LIB}/jade/testing/runner.rb:1", '/app/build/math.rb:9'])

        report([Crashed[%w[T crashes], error]]).then do |output|
          expect(output).to include '/app/build/math.rb:9'
          expect(output).not_to include 'testing/runner.rb'
        end
      end

      it 'counts what happened' do
        expect(report([Passed[%w[T a]], Passed[%w[T b]]]))
          .to include '2 tests, 0 failures (compiled in 1.50s, ran in 250ms)'
        expect(report([Failed[%w[T a], [reason]]]))
          .to include '1 test, 1 failure (compiled in 1.50s, ran in 250ms)'
      end

      it 'prints one mark per test by default, and names them only on request' do
        boom = RuntimeError.new('x').tap { it.set_backtrace(['/app/x.rb:1']) }
        results = [Passed[%w[T a]], Failed[%w[T b], [reason]], Crashed[%w[T c], boom]]

        expect(report(results, format: :dots)).to start_with(".x!\n")
        expect(report(results, format: :doc)).to include('. a')
      end

      it 'wraps a long row of marks' do
        results = Array.new(Reporter::DOTS_PER_LINE + 5) { |i| Passed[['T', i.to_s]] }

        expect(report(results, format: :dots).lines.first.chomp.length).to eql Reporter::DOTS_PER_LINE
      end

      it 'counts a module that never loaded as an error' do
        output = report([], [Broken['MathTest', RuntimeError.new('nope')]])

        expect(output).to include('MathTest').and include('nope')
        expect(output).to include '0 tests, 0 failures, 1 error'
      end
    end
  end
end
