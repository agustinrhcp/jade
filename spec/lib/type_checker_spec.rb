require 'spec_helper'

require 'type_checker'

describe TypeChecker do
  subject { described_class.check(node) }

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

      it 'raises an error' do
        expect { subject }
          .to raise_error(TypeChecker::Error)
      end
    end

    context 'bang bool' do
      let(:node) { uny(:!, lit(true)) }

      it { is_expected.to be :bool }
    end

    context 'bang string' do
      let(:node) { uny(:!, lit('Hello')) }

      it 'raises an error' do
        expect { subject }
          .to raise_error(TypeChecker::Error)
      end
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

          it 'raises an error' do
            expect { subject }
              .to raise_error(TypeChecker::Error)
          end
        end

        context 'bool * int' do
          let(:node) { bin(lit(true), :*, lit(2)) }

          it 'raises an error' do
            expect { subject }
              .to raise_error(TypeChecker::Error)
          end
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

          it 'raises an error' do
            expect { subject }
              .to raise_error(TypeChecker::Error)
          end
        end

        context 'bool == string' do
          let(:node) { bin(lit(true), :==, lit('Hello')) }

          it 'raises an error' do
            expect { subject }
              .to raise_error(TypeChecker::Error)
          end
        end
      end
    end
  end
end
