require 'spec_helper'
require 'jade'
require 'jade/module_loader'

module Jade
  describe 'Examples' do
    include_context 'with test compiler'

    def compile(filename)
      source = File.read(File.join(__dir__, '..', 'examples', filename))
      test_compiler.require(File.basename(filename, '.jd'), source)
    end

    describe 'basics_examples.jd' do
      before { compile('basics_examples.jd') }

      it 'adds two numbers' do
        expect(BasicsExamples.add.call(3, 4)).to eq 7
      end

      it 'greets with a name' do
        expect(BasicsExamples.greet.call('Alice')).to eq 'Hello, Alice!'
      end

      it 'returns the absolute value' do
        expect(BasicsExamples.absolute.call(-5)).to eq 5
        expect(BasicsExamples.absolute.call(3)).to eq 3
      end

      it 'clamps a value' do
        expect(BasicsExamples.clamp.call(5, 1, 10)).to eq 5
        expect(BasicsExamples.clamp.call(-1, 1, 10)).to eq 1
        expect(BasicsExamples.clamp.call(15, 1, 10)).to eq 10
      end
    end

    describe 'pattern_matching.jd' do
      before { compile('pattern_matching.jd') }

      it 'describes a list' do
        expect(PatternMatching.describe_list.call([])).to eq 'empty'
        expect(PatternMatching.describe_list.call([1])).to eq 'one element'
        expect(PatternMatching.describe_list.call([1, 2])).to eq 'multiple elements'
      end

      it 'sums a list' do
        expect(PatternMatching.sum.call([])).to eq 0
        expect(PatternMatching.sum.call([1, 2, 3, 4])).to eq 10
      end

      it 'computes fibonacci' do
        expect(PatternMatching.fibonacci.call(0)).to eq 0
        expect(PatternMatching.fibonacci.call(1)).to eq 1
        expect(PatternMatching.fibonacci.call(7)).to eq 13
      end
    end

    describe 'maybe_examples.jd' do
      before { compile('maybe_examples.jd') }

      it 'divides safely' do
        expect(MaybeExamples.safe_divide.call(10, 2)).to eq Maybe::Just[5]
        expect(MaybeExamples.safe_divide.call(10, 0)).to eq Maybe::Nothing[]
      end

      it 'finds the first matching element' do
        even = ->(x) { x % 2 == 0 }
        expect(MaybeExamples.find_first.call([1, 3, 4, 5], even)).to eq Maybe::Just[4]
        expect(MaybeExamples.find_first.call([1, 3, 5], even)).to eq Maybe::Nothing[]
      end

      it 'chains operations with pipeline' do
        expect(MaybeExamples.pipeline.call(4)).to eq Maybe::Just[13]
        expect(MaybeExamples.pipeline.call(0)).to eq Maybe::Nothing[]
      end
    end

    describe 'custom_types.jd' do
      before { compile('custom_types.jd') }

      it 'describes shapes' do
        expect(CustomTypes.describe.call(CustomTypes::Circle[1.0])).to eq 'circle'
        expect(CustomTypes.describe.call(CustomTypes::Rectangle[2.0, 3.0])).to eq 'rectangle'
        expect(CustomTypes.describe.call(CustomTypes::Triangle[3.0, 4.0, 5.0])).to eq 'triangle'
      end

      it 'computes perimeters' do
        expect(CustomTypes.perimeter.call(CustomTypes::Rectangle[3.0, 4.0])).to be_within(0.001).of(14.0)
        expect(CustomTypes.perimeter.call(CustomTypes::Triangle[3.0, 4.0, 5.0])).to be_within(0.001).of(12.0)
      end
    end

    describe 'interfaces.jd' do
      before { compile('interfaces.jd') }

      it 'returns the larger value' do
        expect(Interfaces.larger.call(3, 7)).to eq 7
        expect(Interfaces.larger.call('b', 'a')).to eq 'b'
      end

      it 'sorts a pair' do
        expect(Interfaces.sort_pair.call(5, 2)).to eq Tuple::Tuple2[2, 5]
        expect(Interfaces.sort_pair.call(1, 3)).to eq Tuple::Tuple2[1, 3]
      end

      it 'checks equality' do
        expect(Interfaces.are_equal.call(1, 1)).to be true
        expect(Interfaces.are_equal.call(1, 2)).to be false
      end
    end
  end
end
