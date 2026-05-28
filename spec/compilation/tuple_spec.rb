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
        end


        def get_first(pair: (Int, String)) -> Int
          Tuple.first(pair)
        end


        def get_second(pair: (Int, String)) -> String
          Tuple.second(pair)
        end


        def swap(pair: (Int, String)) -> (String, Int)
          (Tuple.second(pair), Tuple.first(pair))
        end


        def pattern_matching(int: Int, str: String) -> Int
          case (int, str)
          in (1, "1") then 1
          in (2, "2") then 2
          else 0
          end
        end
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

  describe 'qualified constructor call' do
    include_context 'with test compiler'

    it 'compiles Tuple.Tuple2(...) as a qualified call' do
      test_compiler.require('Quali', <<~JADE)
        module Quali exposing (mk, swap)

        def mk -> (Int, String)
          Tuple.Tuple2(1, "x")
        end


        def swap(t: (a, b)) -> (b, a)
          Tuple.Tuple2(Tuple.second(t), Tuple.first(t))
        end
      JADE

      expect(Quali::Internal.mk).to eql Tuple::Tuple2[1, "x"]
      expect(Quali::Internal.swap(Tuple::Tuple2[1, "x"])).to eql Tuple::Tuple2["x", 1]
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
            else 0
            end
          end
        JADE
      }.to raise_error(CompilationError, /Tuple of 5 items is too big — tuples cap at 4/)
    end

    it 'rejects tuple patterns larger than 4' do
      expect {
        test_compiler.require('BigPat', <<~JADE)
          module BigPat exposing (big)

          def big(t: (Int, Int, Int, Int)) -> Int
            case t
            in (a, _, _, _, _) then a
            end
          end
        JADE
      }.to raise_error(CompilationError, /Tuple of 5 items is too big/)
    end

    it 'rejects tuple types larger than 4' do
      expect {
        test_compiler.require('BigType', <<~JADE)
          module BigType exposing (big)

          def big(t: (Int, Int, Int, Int, Int)) -> Int
            99
          end
        JADE
      }.to raise_error(CompilationError, /Tuple of 5 items is too big/)
    end
  end
end
