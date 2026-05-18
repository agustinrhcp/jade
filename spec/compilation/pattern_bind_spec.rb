require 'spec_helper'

require 'jade'
require 'jade/module_loader'

module Jade
  describe 'Pattern bind' do
    include_context 'with test compiler'

    before do
      test_compiler.require('pattern_bind', source)
    end

    context 'record bind in Maybe context' do
      let(:source) do
        <<~JADE
          module PatternBind exposing (get_name)

          def get_name(m: Maybe({ name: String })) -> Maybe(String)
            { name: } <- m

            Just(name)
          end
        JADE
      end

      it 'extracts the field' do
        expect(PatternBind::Internal.get_name.call(Maybe::Just[{ name: 'Alice' }])).to be_just('Alice')
        expect(PatternBind::Internal.get_name.call(Maybe::Nothing[])).to be_nothing
      end
    end

    context 'tuple pattern in lambda param' do
      let(:source) do
        <<~JADE
          module PatternBind exposing (sum_pair)

          def sum_pair(pair: (Int, Int)) -> Int
            f = ((a, b)) -> { a + b }

            f(pair)
          end
        JADE
      end

      it 'destructures the tuple' do
        expect(PatternBind::Internal.sum_pair.call(Tuple::Tuple2[3, 4])).to eql 7
      end
    end

    context 'record pattern in lambda param' do
      let(:source) do
        <<~JADE
          module PatternBind exposing (get_name_direct)

          def get_name_direct(person: { name: String, age: Int }) -> String
            f = ({ name: }) -> { name }

            f(person)
          end
        JADE
      end

      it 'destructures the record' do
        expect(PatternBind::Internal.get_name_direct.call({ name: 'Bob', age: 25 })).to eql 'Bob'
      end
    end

    context 'list pattern in case' do
      let(:source) do
        <<~JADE
          module PatternBind exposing (sum_list)

          def sum_list(list: List(Int)) -> Int
            case list
            of [] then 0
            of [x | xs] then x + sum_list(xs)
            end
          end
        JADE
      end

      it 'matches empty and non-empty lists' do
        expect(PatternBind.sum_list([])).to eql 0
        expect(PatternBind.sum_list([1, 2, 3])).to eql 6
      end
    end

    context 'list pattern in lambda param' do
      let(:source) do
        <<~JADE
          module PatternBind exposing (first_or_zero)

          def first_or_zero(list: List(Int)) -> Int
            case list
            of [] then 0
            of [x | _] then x
            end
          end
        JADE
      end

      it 'extracts the first element' do
        expect(PatternBind.first_or_zero([])).to eql 0
        expect(PatternBind.first_or_zero([42, 1, 2])).to eql 42
      end
    end

    context 'cons pattern over list of struct' do
      let(:source) do
        <<~JADE
          module PatternBind exposing (head_id)

          struct Charge = {
            id: Int,
            due_cents: Int
          }

          def head_id(xs: List(Charge)) -> Int
            case xs
            of [] then 0
            of [c | rest] then c.id
            end
          end
        JADE
      end

      it 'destructures and projects a struct field' do
        c1 = PatternBind::Charge[1, 100]
        c2 = PatternBind::Charge[2, 200]
        expect(PatternBind.head_id([])).to eql 0
        expect(PatternBind.head_id([c1, c2])).to eql 1
      end
    end

  end

  describe 'Pattern analysis on opaque types' do
    include_context 'with test compiler'

    it "doesn't crash on let-binding over a cross-module struct with a Decode.Value field" do
      test_compiler.require('opaque_lib', <<~JADE)
        module OpaqueLib exposing (T(..), make)

        import Decode exposing (Value)
        import Encode exposing (int)

        struct T = { v: Value }

        def make() -> T
          T(int(1))
        end
      JADE

      test_compiler.require('opaque_app', <<~JADE)
        module OpaqueApp exposing (go)

        import OpaqueLib exposing (T, make)

        def go() -> T
          a = make()

          a
        end
      JADE

      expect(OpaqueApp::Internal.go.call).to be_a(OpaqueLib::T)
    end
  end
end
