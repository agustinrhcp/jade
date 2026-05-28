require 'spec_helper'

require 'jade'
require 'jade/module_loader'

module Jade
  describe 'Pipe into bare lambda' do
    include_context 'with test compiler'

    let(:source) do
      <<~JADE
        module M exposing (chained, double, transform)

        def double(n: Int) -> Int
          n |> (m) -> { m * 2 }
        end


        def transform(n: Int) -> Int
          n |> (m) -> {
            x = m * 2
            x + 1
          }
        end


        def chained(n: Int) -> Int
          n
            |> (m) -> { m * 2 }
            |> (m) -> { m + 1 }
        end
      JADE
    end

    before { test_compiler.require('m', source) }

    it 'pipes a value into a bare lambda' do
      expect(M.double(7)).to eql 14
    end

    it 'supports a multi-statement lambda body after pipe' do
      expect(M.transform(7)).to eql 15
    end

    it 'chains pipes through multiple lambdas' do
      expect(M.chained(7)).to eql 15
    end
  end
end
