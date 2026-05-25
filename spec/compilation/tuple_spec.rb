require 'spec_helper'

require 'jade'
require 'jade/module_loader'

module Jade
  describe 'Tuple' do
    include_context 'with test compiler'

    let(:pepe_source) do
      <<~JADE
        module Pepe exposing (get_first, get_second, make_pair, pattern_matching, swap)

        def make_pair(a: Int, b: String) -> (Int, String)
          (a, b)


        def get_first(pair: (Int, String)) -> Int
          Tuple.first(pair)


        def get_second(pair: (Int, String)) -> String
          Tuple.second(pair)


        def swap(pair: (Int, String)) -> (String, Int)
          (Tuple.second(pair), Tuple.first(pair))


        def pattern_matching(int: Int, str: String) -> Int
          case (int, str)
          of (1, "1") -> 1
          of (2, "2") -> 2
          of _ -> 0
      JADE
    end

    before do
      test_compiler.require('pepe', pepe_source)
    end

    it 'works' do
      expect(Pepe::Internal.make_pair(1, "hello")).to eql Tuple::Tuple2[1, "hello"]
      expect(Pepe::Internal.get_first(Tuple::Tuple2[1, "hello"])).to eql 1
      expect(Pepe::Internal.get_second(Tuple::Tuple2[1, "hello"])).to eql "hello"
      expect(Pepe::Internal.swap(Tuple::Tuple2[1, "hello"])).to eql Tuple::Tuple2["hello", 1]
      expect(Pepe.pattern_matching(1, "1")).to eql 1
      expect(Pepe.pattern_matching(3, "3")).to eql 0
    end
  end

  describe 'tuple arity cap' do
    include_context 'with test compiler'

    around { |ex| ENV['JADE_SKIP_FORMAT_CHECK'] = '1'; ex.run; ENV.delete('JADE_SKIP_FORMAT_CHECK') }

    it 'rejects value tuples larger than 4' do
      expect {
        test_compiler.require('BigVal', <<~JADE)
          module BigVal exposing (big)


          def big -> Int
            case (1, 2, 3, 4, 5)
            of _ -> 0
        JADE
      }.to raise_error(CompilationError, /Tuple of 5 items is too big — tuples cap at 4/)
    end

    it 'rejects tuple patterns larger than 4' do
      expect {
        test_compiler.require('BigPat', <<~JADE)
          module BigPat exposing (big)


          def big(t: (Int, Int, Int, Int)) -> Int
            case t
            of (a, _, _, _, _) -> a
        JADE
      }.to raise_error(CompilationError, /Tuple of 5 items is too big/)
    end

    it 'rejects tuple types larger than 4' do
      expect {
        test_compiler.require('BigType', <<~JADE)
          module BigType exposing (big)


          def big(t: (Int, Int, Int, Int, Int)) -> Int
            99
        JADE
      }.to raise_error(CompilationError, /Tuple of 5 items is too big/)
    end
  end
end
