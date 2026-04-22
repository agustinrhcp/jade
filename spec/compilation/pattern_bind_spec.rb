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
        expect(PatternBind.get_name.call(Maybe::Just[{ name: 'Alice' }])).to eql Maybe::Just['Alice']
        expect(PatternBind.get_name.call(Maybe::Nothing[])).to eql Maybe::Nothing[]
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
  end
end
