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
            n == 0 ? 1 : n * fact(n - 1)
          end
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
            (n <= 1) ? n : fib(n - 1) + fib(n - 2)
          end
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
            in [] then acc
            in [_ | rest] then length(rest, acc + 1)
            end
          end
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
            in [] then acc
            in [x | rest] then sum(rest, acc + x)
            end
          end
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
            (n == 0) ? acc : count(n - 1, acc + 1)
          end
        JADE
      end

      it 'survives 50k iterations' do
        expect(TrCountdown.count(50_000, 0)).to eql 50_000
      end
    end

    context 'fold-shape naive length' do
      before do
        test_compiler.require('fold_length', source)
      end

      let(:source) do
        <<~JADE
          module FoldLength exposing (length)

          def length(xs: List(Int)) -> Int
            case xs
            in [] then 0
            in [_ | rest] then 1 + length(rest)
            end
          end
        JADE
      end

      it 'computes the length correctly' do
        expect(FoldLength.length([])).to eql 0
        expect(FoldLength.length([1, 2, 3])).to eql 3
      end

      it 'survives a 50k-element list' do
        expect(FoldLength.length((1..50_000).to_a)).to eql 50_000
      end

      it 'emits a reduce, not a recursive call' do
        ruby = test_compiler.generated_source('fold_length')
        expect(ruby).to include('.reverse.reduce(')
        expect(ruby).to include('__fold_acc__')
      end
    end

    context 'fold-shape naive sum' do
      before do
        test_compiler.require('fold_sum', source)
      end

      let(:source) do
        <<~JADE
          module FoldSum exposing (sum)

          def sum(xs: List(Int)) -> Int
            case xs
            in [] then 0
            in [x | rest] then x + sum(rest)
            end
          end
        JADE
      end

      it 'computes the sum and survives 50k' do
        expect(FoldSum.sum([1, 2, 3, 4])).to eql 10
        expect(FoldSum.sum((1..50_000).to_a)).to eql (1..50_000).sum
      end
    end

    # Soundness guards: shapes that LOOK like a fold but aren't safe to
    # rewrite. Each one should fall through to default codegen, NOT take the
    # `.reverse.reduce(...)` path.

    context 'fold-shape guards: `rest` referenced outside the recursive call' do
      before do
        test_compiler.require('rest_leak', source)
      end

      let(:source) do
        <<~JADE
          module RestLeak exposing (f)

          def f(xs: List(Int)) -> Int
            case xs
            in [] then 0
            in [_ | rest] then List.length(rest) + f(rest)
            end
          end
        JADE
      end

      it 'does NOT fold-rewrite — `rest` would become unbound in the block' do
        ruby = test_compiler.generated_source('rest_leak')
        expect(ruby).not_to include('.reverse.reduce(')
      end

      it 'still computes correctly via default (recursive) codegen' do
        # f([a,b,c]) = len([b,c]) + len([c]) + len([]) + 0 = 2 + 1 + 0 + 0 = 3
        expect(RestLeak.f([10, 20, 30])).to eql 3
      end
    end

    context 'fold-shape guards: self-call buried in a lambda body' do
      before do
        test_compiler.require('lambda_buried', source)
      end

      let(:source) do
        <<~JADE
          module LambdaBuried exposing (f)

          def f(xs: List(Int)) -> Int
            case xs
            in [] then 0
            in [_ | rest] then (-> { 1 + f(rest) })()
            end
          end
        JADE
      end

      it 'does NOT fold-rewrite — the self-call sits in a lazy position' do
        ruby = test_compiler.generated_source('lambda_buried')
        expect(ruby).not_to include('.reverse.reduce(')
      end
    end
  end
end
