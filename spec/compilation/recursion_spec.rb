require 'spec_helper'

require 'jade'
require 'jade/module_loader'

module Jade
  describe 'Recursion' do
    include_context 'with test compiler'

    context 'factorial' do
      before do
        test_compiler.require('fact', fact_source)
      end

      let(:fact_source) do
        <<~JADE
          module Fact exposing (fact)

          def fact(n: Int) -> Int
            if n == 0 then 1 else n * fact(n - 1)
        JADE
      end

      it 'returns the factorial' do
        expect(Fact.fact(10)).to eql 3_628_800
      end
    end

    context 'fib' do
      before do
        test_compiler.require('fib', fib_source)
      end

      let(:fib_source) do
        <<~JADE
          module Fib exposing (fib)

          def fib(n: Int) -> Int
            if (n <= 1) then n else fib(n - 1) + fib(n - 2)
        JADE
      end

      it 'returns the factorial' do
        expect(Fib.fib(10)).to eql 55
      end
    end

    context 'tail-recursive length (case shape)' do
      before do
        test_compiler.require('tr_length', source)
      end

      let(:source) do
        <<~JADE
          module TrLength exposing (length)

          def length(xs: List(Int), acc: Int) -> Int
            case xs
            of [] -> acc
            of [_ | rest] -> length(rest, acc + 1)
        JADE
      end

      it 'compiles to a loop and survives a 50k-element list' do
        expect(TrLength.length((1..50_000).to_a, 0)).to eql 50_000
      end

      it 'emits a loop, not a recursive .call' do
        ruby = test_compiler.generated_source('tr_length')
        expect(ruby).to include('loop do')
        expect(ruby).to include('xs, acc = rest,')
        expect(ruby).to include('break acc')
      end
    end

    context 'tail-recursive sum (case shape, different op)' do
      before do
        test_compiler.require('tr_sum', source)
      end

      let(:source) do
        <<~JADE
          module TrSum exposing (sum)

          def sum(xs: List(Int), acc: Int) -> Int
            case xs
            of [] -> acc
            of [x | rest] -> sum(rest, acc + x)
        JADE
      end

      it 'survives a 50k-element list' do
        expect(TrSum.sum((1..50_000).to_a, 0)).to eql (1..50_000).sum
      end
    end

    context 'tail-recursive countdown (if/then/else shape)' do
      before do
        test_compiler.require('tr_countdown', source)
      end

      let(:source) do
        <<~JADE
          module TrCountdown exposing (count)

          def count(n: Int, acc: Int) -> Int
            if (n == 0) then acc else count(n - 1, acc + 1)
        JADE
      end

      it 'survives 50k iterations' do
        expect(TrCountdown.count(50_000, 0)).to eql 50_000
      end
    end
  end
end
