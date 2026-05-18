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
        expect(BasicsExamples.add(3, 4)).to eq 7
      end

      it 'greets with a name' do
        expect(BasicsExamples.greet('Alice')).to eq 'Hello, Alice!'
      end

      it 'returns the absolute value' do
        expect(BasicsExamples.absolute(-5)).to eq 5
        expect(BasicsExamples.absolute(3)).to eq 3
      end

      it 'clamps a value' do
        expect(BasicsExamples.clamp(5, 1, 10)).to eq 5
        expect(BasicsExamples.clamp(-1, 1, 10)).to eq 1
        expect(BasicsExamples.clamp(15, 1, 10)).to eq 10
      end
    end

    describe 'pattern_matching.jd' do
      before { compile('pattern_matching.jd') }

      it 'describes a list' do
        expect(PatternMatching.describe_list([])).to eq 'empty'
        expect(PatternMatching.describe_list([1])).to eq 'one element'
        expect(PatternMatching.describe_list([1, 2])).to eq 'multiple elements'
      end

      it 'sums a list' do
        expect(PatternMatching.sum([])).to eq 0
        expect(PatternMatching.sum([1, 2, 3, 4])).to eq 10
      end

      it 'computes fibonacci' do
        expect(PatternMatching.fibonacci(0)).to eq 0
        expect(PatternMatching.fibonacci(1)).to eq 1
        expect(PatternMatching.fibonacci(7)).to eq 13
      end
    end

    describe 'maybe_examples.jd' do
      before { compile('maybe_examples.jd') }

      it 'divides safely' do
        expect(MaybeExamples.safe_divide(10, 2)).to eql 5
        expect(MaybeExamples.safe_divide(10, 0)).to be_nil
      end

      it 'finds the first matching element' do
        # find_first takes a `Int -> Bool` predicate, which isn't decodable
        # at the boundary — call through Internal so we can pass a lambda.
        even = ->(x) { x % 2 == 0 }
        expect(MaybeExamples::Internal.find_first.call([1, 3, 4, 5], even)).to be_just(4)
        expect(MaybeExamples::Internal.find_first.call([1, 3, 5], even)).to be_nothing
      end

      it 'chains operations with pipeline' do
        expect(MaybeExamples.pipeline(4)).to eql 13
        expect(MaybeExamples.pipeline(0)).to be_nil
      end
    end

    describe 'custom_types.jd' do
      before { compile('custom_types.jd') }

      it 'describes shapes' do
        expect(CustomTypes::Internal.describe.call(CustomTypes::Circle[1.0])).to eq 'circle'
        expect(CustomTypes::Internal.describe.call(CustomTypes::Rectangle[2.0, 3.0])).to eq 'rectangle'
        expect(CustomTypes::Internal.describe.call(CustomTypes::Triangle[3.0, 4.0, 5.0])).to eq 'triangle'
      end

      it 'computes perimeters' do
        expect(CustomTypes::Internal.perimeter.call(CustomTypes::Rectangle[3.0, 4.0])).to be_within(0.001).of(14.0)
        expect(CustomTypes::Internal.perimeter.call(CustomTypes::Triangle[3.0, 4.0, 5.0])).to be_within(0.001).of(12.0)
      end
    end

    describe 'interfaces.jd' do
      # Polymorphic helpers — no public boundary; just confirm it compiles.
      it 'compiles' do
        expect { compile('interfaces.jd') }.not_to raise_error
      end
    end
  end
end
