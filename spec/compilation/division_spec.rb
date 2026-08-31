require 'spec_helper'

require 'jade'
require 'jade/module_loader'

module Jade
  # `a / b` used to raise `ZeroDivisionError` out of Ruby, so a signature
  # reading `Int -> Int -> Int` was not as total as it looked.
  describe 'division' do
    include_context 'with test compiler'

    def compile(source)
      test_compiler.require(source)
    end

    context 'by a literal' do
      before do
        compile(<<~JADE.strip)
          module Rates exposing (halve, to_euros)

          def to_euros(cents: Int) -> Int
            cents / 100
          end


          def halve(f: Float) -> Float
            f / 2.0
          end
        JADE
      end

      it 'divides, with nothing written around it' do
        expect(Rates.to_euros(250)).to eq 2
      end

      it 'works the same for floats' do
        expect(Rates.halve(5.0)).to eq 2.5
      end
    end

    context 'by a value' do
      before do
        compile(<<~JADE.strip)
          module Shares exposing (each)

          def each(total: Int, people: Int) -> Maybe(Int)
            Maybe.map(non_zero(people), (d) -> { total / d })
          end
        JADE
      end

      it 'divides once the value is known not to be zero' do
        expect(Shares.each(10, 4)).to eq 2
      end

      it 'has nothing to divide by when it is zero' do
        expect(Shares.each(10, 0)).to be_nil
      end
    end

    describe 'what the compiler refuses' do
      def errors(source, file)
        Dir.mktmpdir do |root|
          Dir.mkdir(File.join(root, 'src'))
          File.write(File.join(root, "src/#{file}"), source)
          ModuleLoader
            .load(File.join(root, 'src'), file, tolerant: true)
            .modules
            .each_value
            .reject { Stdlib.is_stdlib?(it) }
            .flat_map { it.diagnostics.items }
            .map(&:message)
        end
      end

      it 'names a literal zero as the problem, and says nothing else' do
        expect(errors(<<~JADE.strip, 'zero_div.jd')).to eq ['Cannot divide by zero.']
          module ZeroDiv exposing (bad)

          def bad(n: Int) -> Int
            n / 0
          end
        JADE
      end

      it 'asks for a NonZero when the divisor is a value' do
        source = <<~JADE.strip
          module ValueDiv exposing (bad)

          def bad(n: Int, d: Int) -> Int
            n / d
          end
        JADE

        expect(errors(source, 'value_div.jd'))
          .to eq ['Right side of (/) expects NonZero(Int) but found Int']
      end
    end

    describe 'non_zero' do
      before do
        compile(<<~JADE.strip)
          module Checked exposing (check)

          def check(n: Int) -> Maybe(Int)
            Maybe.map(non_zero(n), (d) -> { 100 / d })
          end
        JADE
      end

      it 'gives nothing for zero' do
        expect(Checked.check(0)).to be_nil
      end

      it 'gives the value for anything else' do
        expect(Checked.check(4)).to eq 25
      end
    end
  end
end
