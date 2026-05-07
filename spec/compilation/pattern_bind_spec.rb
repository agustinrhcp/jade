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
        expect(PatternBind.get_name.call(Maybe::Just[{ name: 'Alice' }])).to be_just('Alice')
        expect(PatternBind.get_name.call(Maybe::Nothing[])).to be_nothing
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
        expect(PatternBind.sum_pair.call(Tuple::Tuple2[3, 4])).to eql 7
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
        expect(PatternBind.get_name_direct.call({ name: 'Bob', age: 25 })).to eql 'Bob'
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
        expect(PatternBind.sum_list.call([])).to eql 0
        expect(PatternBind.sum_list.call([1, 2, 3])).to eql 6
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
        expect(PatternBind.first_or_zero.call([])).to eql 0
        expect(PatternBind.first_or_zero.call([42, 1, 2])).to eql 42
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
        expect(PatternBind.head_id.call([])).to eql 0
        expect(PatternBind.head_id.call([c1, c2])).to eql 1
      end
    end
  end
end
