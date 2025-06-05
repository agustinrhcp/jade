require 'spec_helper'

require 'type_checker'
require 'scope'

describe TypeChecker do
  let(:scope) { Scope.new }
  let(:result) { described_class.check(node, scope) }
  subject { result => Ok([type, _]); type }

  context 'for an integer' do
    let(:node) { lit(2) }

    it { is_expected.to eql Type.int }
  end

  context 'for a boolean' do
    let(:node) { lit(false) }

    it { is_expected.to eql Type.bool }
  end

  context 'for a string' do
    let(:node) { lit('Hello') }

    it { is_expected.to eql Type.string }
  end

  context 'a unary operation' do
    context 'minus int' do
      let(:node) { uny(:-, lit(4)) }

      it { is_expected.to eql Type.int }
    end

    context 'minus bool' do
      let(:node) { uny(:-, lit(true)) }
      subject { result => Err(error); error }

      its(:message) { is_expected.to eql "Unary '-' not valid for Bool" }
    end

    context 'bang bool' do
      let(:node) { uny(:!, lit(true)) }

      it { is_expected.to eql Type.bool }
    end

    context 'bang string' do
      let(:node) { uny(:!, lit('Hello')) }
      subject { result => Err(error); error }

      its(:message) { is_expected.to eql "Unary '!' not valid for String" }
    end
  end

  context 'a binary operation' do
    context 'arithmetic operations' do
      context 'addition' do
        let(:node) { bin(lit(2), :+, lit(3)) }

        it { is_expected.to eql Type.int }
      end

      context 'subtraction' do
        let(:node) { bin(lit(5), :-, lit(3)) }

        it { is_expected.to eql Type.int }
      end

      context 'multiplication' do
        let(:node) { bin(lit(2), :*, lit(3)) }

        it { is_expected.to eql Type.int }
      end

      context 'division' do
        let(:node) { bin(lit(6), :/, lit(2)) }

        it { is_expected.to eql Type.int }
      end

      context 'invalid operands' do
        context 'string + int' do
          let(:node) { bin(lit('Hello'), :+, lit(2)) }
          subject { result => Err(error); error }

          its(:message) { is_expected.to eql "Left operand of '+' must be Int, got String" }
        end

        context 'bool * int' do
          let(:node) { bin(lit(true), :*, lit(2)) }
          subject { result => Err(error); error }

          its(:message) { is_expected.to eql "Left operand of '*' must be Int, got Bool" }
        end
      end
    end

    context 'comparison operations' do
      context 'less than' do
        let(:node) { bin(lit(2), :<, lit(3)) }

        it { is_expected.to eql Type.bool }
      end

      context 'less than or equal' do
        let(:node) { bin(lit(2), :<=, lit(2)) }

        it { is_expected.to eql Type.bool }
      end

      context 'greater than' do
        let(:node) { bin(lit(3), :>, lit(2)) }

        it { is_expected.to eql Type.bool }
      end

      context 'greater than or equal' do
        let(:node) { bin(lit(3), :>=, lit(3)) }

        it { is_expected.to eql Type.bool }
      end

      context 'equal' do
        let(:node) { bin(lit(2), :==, lit(2)) }

        it { is_expected.to eql Type.bool }
      end

      context 'not equal' do
        let(:node) { bin(lit(2), :!=, lit(3)) }

        it { is_expected.to eql Type.bool }
      end

      context 'invalid operands' do
        context 'string < int' do
          let(:node) { bin(lit('Hello'), :<, lit(2)) }
          subject { result => Err(error); error }

          its(:message) { is_expected.to eql "Left operand of '<' must be Int, got String" }
        end

        context 'bool == string' do
          let(:node) { bin(lit(true), :==, lit('Hello')) }
          subject { result => Err(error); error }

          its(:message) { is_expected.to eql "Right operand of '==' must be Bool, got String" }
        end
      end
    end
  end

  context 'variables and declarations' do
    context 'a declared variable' do
      let(:node) { var('x') }
      let(:scope) { Scope.new.define_typed_var('x', Type.int, nil) }

      it { is_expected.to eql Type.int }
    end

    context 'an undeclared variable' do
      let(:node) { var('y') }
      subject { result => Err(error); error }

      its(:message) { is_expected.to eql "Undefined variable 'y'" }
    end

    context 'a variable declaration' do
      let(:node) { var_dec('z', lit(42)) }

      context 'the returned scope' do
        subject { result => Ok([_, scope]); scope }

        it 'adds the variable type to the scope' do
          expect(subject.resolve(:z).type).to eql Type.int
        end
      end

      it { is_expected.to eql Type.int }

      context 'a string' do
        let(:scope) { Scope.new.define_unbound_var('z', nil) }
        let(:node) { var_dec('z', lit('Alo')) }

        context 'the returned scope' do
          subject { result => Ok([_, scope]); scope }

          it 'adds the variable type to the scope' do
            subject.resolve(:z) => TypedVar(type:)
            expect(type).to eql Type.string
          end
        end

        it { is_expected.to eql Type.string }
      end
    end

    context 'function declarations' do
      let(:node) { fn_dec('double', params(param('n', Type.int)), Type.int, bin(var('n'), :*, lit(2))) }

      it { is_expected.to be_a(Type::Function) }
      its(:parameters) { is_expected.to eql [Type.int] }
      its(:return_type) { is_expected.to eql Type.int }
    end
  end

  context 'function calls' do
    let(:fn_type) { Type::Function.new([Type.int], Type.int) }
    let(:scope) { Scope.new.define_typed_function('double', fn_type, nil) }

    context 'valid calls' do
      let(:node) { fn_call('double', lit(42)) }

      it { is_expected.to eql Type.int }
    end

    context 'invalid calls' do
      subject { result => Err(error); error }

      context 'argument type mismatch' do
        let(:node) { fn_call('double', lit('hello')) }

        its(:message) { is_expected.to eql "Expected argument 0 of type Int, got String" }
      end

      context 'multiple arguments with type mismatch' do
        let(:fn_type) { Type::Function.new([Type.int, Type.string], Type.int) }
        let(:node) { fn_call('double', lit(42), lit(43)) }

        its(:message) { is_expected.to eql "Expected argument 1 of type String, got Int" }
      end
    end
  end
end
