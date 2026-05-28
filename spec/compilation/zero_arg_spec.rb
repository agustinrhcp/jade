require 'spec_helper'

require 'jade'
require 'jade/module_loader'

module Jade
  describe 'zero-arg constructors and functions' do
    include_context 'with test compiler'

    context 'zero-arg function used as bare reference' do
      let(:src) do
        <<~JADE
          module ZeroArgFn exposing (double_pi, pi)

          def pi -> Float
            3.14
          end


          def double_pi -> Float
            pi + pi
          end
        JADE
      end

      it 'compiles and runs' do
        test_compiler.require('zero_arg_fn', src)
        expect(ZeroArgFn.pi).to be_within(0.001).of(3.14)
        expect(ZeroArgFn.double_pi).to be_within(0.001).of(6.28)
      end
    end

    context 'zero-arg constructor as bare reference' do
      let(:src) do
        <<~JADE
          module ZeroArgCtor exposing (bare, ordering_label)

          def bare -> Maybe(Int)
            Nothing
          end


          def ordering_label(x: Int, y: Int) -> String
            case Basics.compare(x, y)
            in LT then "less"
            in EQ then "equal"
            in GT then "greater"
            end
          end
        JADE
      end

      it 'compiles and runs' do
        test_compiler.require('zero_arg_ctor', src)
        expect(ZeroArgCtor.bare).to be_nil
        expect(ZeroArgCtor.ordering_label(1, 2)).to eql "less"
        expect(ZeroArgCtor.ordering_label(2, 2)).to eql "equal"
        expect(ZeroArgCtor.ordering_label(3, 2)).to eql "greater"
      end
    end

    context 'explicit zero-arg call' do
      it 'rejects `Nothing()` with a clear error' do
        src = <<~JADE
          module BadCtor exposing (x)

          def x -> Maybe(Int)
            Nothing()
          end
        JADE

        expect { test_compiler.require('bad_ctor', src) }
          .to raise_error(Jade::CompilationError, /`Nothing` is a value, not a function/)
      end

      it 'rejects `pi()` for a zero-arg fn' do
        src = <<~JADE
          module BadFn exposing (twice)

          def pi -> Float
            3.14
          end


          def twice -> Float
            pi() + pi()
          end
        JADE

        expect { test_compiler.require('bad_fn', src) }
          .to raise_error(Jade::CompilationError, /`pi` is a value, not a function/)
      end
    end

    context 'zero-arg fn whose return type is a function' do
      let(:src) do
        <<~JADE
          module ZeroArgFnReturnsFn exposing (apply_with_1)

          def just_fn -> (Int -> Maybe(Int))
            Just
          end


          def apply_with_1 -> Maybe(Int)
            just_fn(1)
          end
        JADE
      end

      it 'compiles and runs' do
        test_compiler.require('zero_arg_fn_returns_fn', src)
        expect(ZeroArgFnReturnsFn.apply_with_1).to eql 1
      end
    end

    context 'zero-arg function used inside a lambda body' do
      let(:src) do
        <<~JADE
          module PiInLambda exposing (eval_at)

          def pi -> Float
            3.14
          end


          def eval_at -> Float
            0 |> (_) -> { pi }
          end
        JADE
      end

      it 'compiles and runs' do
        test_compiler.require('pi_in_lambda', src)
        expect(PiInLambda.eval_at).to be_within(0.001).of(3.14)
      end
    end
  end
end
