require 'spec_helper'

module Jade
  # The examples are the closest thing here to an app: unions, records,
  # recursion, Maybe, an interface resolved through a dictionary. Running
  # them with no jade on the load path is the evidence behind "you can
  # leave".
  describe 'the ejected examples' do
    # Ruby cannot call a constrained function, which takes its witness as
    # an argument, so dictionary passing needs a monomorphic caller.
    USES = <<~JADE
      module Uses exposing (bigger)

      import Interfaces exposing (larger)


      def bigger -> Int
        larger(3, 7)
      end
    JADE

    include_context 'with an ejected project',
                    %w[basics_examples custom_types interfaces maybe_examples
                       pattern_matching records],
                    'uses' => USES

    it 'runs a function over the stdlib' do
      expect(ejected.run('basics_examples', 'BasicsExamples.clamp(1, 10, 42)')).to eq '10'
    end

    it 'matches on a union it defines' do
      expect(ejected.run('custom_types', 'CustomTypes::Internal.describe(CustomTypes::Circle[2.0])'))
        .to eq 'circle'
    end

    it 'dispatches an interface without the compiler that resolved it' do
      expect(ejected.run('uses', 'Uses.bigger')).to eq '7'
    end

    it 'carries Maybe across the boundary' do
      expect(ejected.run('maybe_examples', 'MaybeExamples.safe_divide(10, 0).inspect'))
        .to include 'nil'
    end

    it 'recurses' do
      expect(ejected.run('pattern_matching', 'PatternMatching.fibonacci(10)')).to eq '55'
    end

    it 'builds a record and reads it back' do
      expect(ejected.run('records', 'Records::Internal.full_name("Ada", "Lovelace").full'))
        .to eq 'Ada Lovelace'
    end

    it 'keeps the Ruby boundary' do
      expect(ejected.run('basics_examples', 'BasicsExamples.greet("you")')).to include 'you'
    end

    it 'leaves no require that would look for the gem' do
      expect(ejected.files.select { File.read(it).match?(/require ['"]jade/) }).to be_empty
    end
  end
end
