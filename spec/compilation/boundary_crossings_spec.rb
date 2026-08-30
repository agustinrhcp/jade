require 'spec_helper'

require 'jade'
require 'jade/module_loader'

module Jade
  # The cost of a crossing follows the data it carries, and the usual way
  # that is discovered is someone concluding Jade is slow.
  describe 'counting boundary crossings' do
    include_context 'with test compiler'

    before do
      test_compiler.require(<<~JADE.strip)
        module Priced exposing (many, one)

        def one(n: Int) -> Int
          n * 2
        end


        def many(ns: List(Int)) -> List(Int)
          List.map(ns, one)
        end
      JADE
    end

    after { Interop::Boundary.unwatch }

    it 'counts one crossing per call' do
      Interop::Boundary.watch(after: 10**9)
      3.times { Priced.one(2) }

      expect(Interop::Boundary.stats).to eq('Priced.one' => 3)
    end

    it 'counts once for a list that could have been a loop' do
      Interop::Boundary.watch(after: 10**9)
      Priced.many([1, 2, 3])

      expect(Interop::Boundary.stats).to eq('Priced.many' => 1)
    end

    it 'warns once, naming the function' do
      Interop::Boundary.watch(after: 2)

      expect { 5.times { Priced.one(2) } }
        .to output(/Priced.one crossed the Ruby boundary 2 times in 0.0s/).to_stderr
    end

    it 'stays quiet for calls spread out over time' do
      Interop::Boundary.watch(after: 2, window: 0.05)

      expect { 5.times { Priced.one(2); sleep 0.06 } }.not_to output.to_stderr
    end

    it 'still counts what it does not warn about' do
      Interop::Boundary.watch(after: 2, window: 0.05)
      5.times { Priced.one(2); sleep 0.06 }

      expect(Interop::Boundary.stats).to eq('Priced.one' => 5)
    end

    it 'counts nothing until asked' do
      expect(Interop::Boundary).not_to be_watching
    end
  end
end
