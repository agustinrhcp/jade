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
            if n == 0 then
              1
            else
              n * fact(n - 1)
            end
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
            if (n <= 1) then
              n
            else
              fib(n - 1) + fib(n - 2)
            end
          end
        JADE
      end

      it 'returns the factorial' do
        expect(Fib.fib(10)).to eql 55
      end
    end
  end
end
