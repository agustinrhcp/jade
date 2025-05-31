require 'spec_helper'

require 'type_checker'

describe TypeChecker do
  let(:env) { TypeChecker::Env.new }
  let(:result) { described_class.check(node, env) }
  subject { result => Ok([type, _]); type }

  context 'for an integer' do
    let(:node) { lit(2) }

    it { is_expected.to eql :int }
  end

  context 'for a boolean' do
    let(:node) { lit(false) }

    it { is_expected.to eql :bool }
  end

  context 'for a string' do
    let(:node) { lit('Hello') }

    it { is_expected.to eql :string }
  end

  context 'a unary operation' do
    context 'minus int' do
      let(:node) { uny(:-, lit(4)) }

      it { is_expected.to eql :int }
    end

    context 'minus bool' do
      let(:node) { uny(:-, lit(true)) }
      subject { result => Err(error); error }

      its(:message) { is_expected.to eql "Unary '-' not valid for bool" }
    end

    context 'bang bool' do
      let(:node) { uny(:!, lit(true)) }

      it { is_expected.to be :bool }
    end

    context 'bang string' do
      let(:node) { uny(:!, lit('Hello')) }
      subject { result => Err(error); error }

      its(:message) { is_expected.to eql "Unary '!' not valid for string" }
    end
  end

  context 'a binary operation' do
    context 'arithmetic operations' do
      context 'addition' do
        let(:node) { bin(lit(2), :+, lit(3)) }

        it { is_expected.to eql :int }
      end

      context 'subtraction' do
        let(:node) { bin(lit(5), :-, lit(3)) }

        it { is_expected.to eql :int }
      end

      context 'multiplication' do
        let(:node) { bin(lit(2), :*, lit(3)) }

        it { is_expected.to eql :int }
      end

      context 'division' do
        let(:node) { bin(lit(6), :/, lit(2)) }

        it { is_expected.to eql :int }
      end

      context 'invalid operands' do
        context 'string + int' do
          let(:node) { bin(lit('Hello'), :+, lit(2)) }
          subject { result => Err(error); error }

          its(:message) { is_expected.to eql "Left operand of '+' must be int, got string" }
        end

        context 'bool * int' do
          let(:node) { bin(lit(true), :*, lit(2)) }
          subject { result => Err(error); error }

          its(:message) { is_expected.to eql "Left operand of '*' must be int, got bool" }
        end
      end
    end

    context 'comparison operations' do
      context 'less than' do
        let(:node) { bin(lit(2), :<, lit(3)) }

        it { is_expected.to eql :bool }
      end

      context 'less than or equal' do
        let(:node) { bin(lit(2), :<=, lit(2)) }

        it { is_expected.to eql :bool }
      end

      context 'greater than' do
        let(:node) { bin(lit(3), :>, lit(2)) }

        it { is_expected.to eql :bool }
      end

      context 'greater than or equal' do
        let(:node) { bin(lit(3), :>=, lit(3)) }

        it { is_expected.to eql :bool }
      end

      context 'equal' do
        let(:node) { bin(lit(2), :==, lit(2)) }

        it { is_expected.to eql :bool }
      end

      context 'not equal' do
        let(:node) { bin(lit(2), :!=, lit(3)) }

        it { is_expected.to eql :bool }
      end

      context 'invalid operands' do
        context 'string < int' do
          let(:node) { bin(lit('Hello'), :<, lit(2)) }
          subject { result => Err(error); error }

          its(:message) { is_expected.to eql "Left operand of '<' must be int, got string" }
        end

        context 'bool == string' do
          let(:node) { bin(lit(true), :==, lit('Hello')) }
          subject { result => Err(error); error }

          its(:message) { is_expected.to eql "Right operand of '==' must be bool, got string" }
        end
      end
    end
  end

  context 'variables and declarations' do
    context 'a declared variable' do
      let(:node) { var('x') }
      let(:env) { TypeChecker::Env.new.define('x', :int) }

      it { is_expected.to eql :int }
    end

    context 'an undeclared variable' do
      let(:node) { var('y') }
      subject { result => Err(error); error }

      its(:message) { is_expected.to eql "Undefined variable 'y'" }
    end

    context 'a variable declaration' do
      let(:node) { var_dec('z', lit(42)) }

      context 'the returned env' do
        subject { result => Ok([_, env]); env }

        it 'adds the variable to the environment' do
          expect(subject.resolve(:z)).to eql :int
        end
      end

      it { is_expected.to eql :int }
    end
  end
end
