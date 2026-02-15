require 'spec_helper'

require 'jade'

module Jade
  describe Frontend::TypeChecking::Unification do
    let(:env) { Frontend::TypeChecking::Env.empty }
    subject { described_class.unify(type1, type2, env) }

    describe 'unifying variables' do
      let(:type1) { Type.var('t1') }
      let(:type2) { Type.var('t2') }

      it { is_expected.to be_ok }

      describe 'the substitution' do
        subject { super() => Ok(substitution); substitution }

        its(:mappings) { is_expected.to include('t1' => Type.var('t2')) }
      end

      context 'unifying two rigid vars' do
        context 'same rigid var' do
          let(:type1) { Type.var('t1').make_rigid }
          let(:type2) { Type.var('t1').make_rigid }

          it { is_expected.to be_ok }
        end

        context 'different rigid vars' do
          let(:type1) { Type.var('t1').make_rigid }
          let(:type2) { Type.var('t2').make_rigid }

          it { is_expected.to be_error }
        end
      end

      context 'unifying flexible against rigid' do
        let(:type1) { Type.var('t1') }
        let(:type2) { Type.var('t2').make_rigid }

        it { is_expected.to be_error }
      end
    end

    describe 'unifying variable with anything else' do
      let(:type1) { Type.var('t1') }
      let(:type2) { Type.int }

      it { is_expected.to be_ok }

      describe 'the substitution' do
        subject { super() => Ok(substitution); substitution }

        its(:mappings) { is_expected.to include('t1' => Type.int) }
      end

      context 'passing the types the other way around' do
        let(:type1) { Type.int }
        let(:type2) { Type.var('t1') }

        it { is_expected.to be_ok }

        describe 'the substitution' do
          subject { super() => Ok(substitution); substitution }

          its(:mappings) { is_expected.to include('t1' => Type.int) }
        end
      end
    end

    describe 'unifying functions' do
      let(:type1) { Type.function([Type.var('t1')], Type.var('t1')) }
      let(:type2) { Type.function([Type.var('t2')], Type.var('t1')) }

      it { is_expected.to be_ok }

      describe 'the substitution' do
        subject { super() => Ok(substitution); substitution }

        its(:mappings) { is_expected.to include('t1' => Type.var('t2')) }
      end

      context 'when the vars are rigid' do
        let(:type1) { Type.function([Type.var('t1')], Type.var('t1')) }
        let(:type2) { Type.function([Type.var('t2').make_rigid], Type.var('t1')) }

        it { is_expected.to be_error }
      end
    end

    describe 'unifying constructors' do
      let(:type1) { Type.int }
      let(:type2) { Type.int }

      it { is_expected.to be_ok }

      describe 'the substitution' do
        subject { super() => Ok(substitution); substitution }

        its(:mappings) { is_expected.to be_empty }
      end

      context 'with different constructors' do
        let(:type2) { Type.string }

        it { is_expected.to be_error }
      end
    end

    describe 'unifying struct with open record' do
      let(:type1) { Type.anonymous_record({ name: Type.string }, Type.var('t1')) }
      let(:type2) { Type.constructor("__Test__.Person") }

      let(:env) do
        Frontend::TypeChecking::TypeDef[
          "__Test__.Person",
          [],
          Type.anonymous_record({ name: Type.string, age: Type.int }, nil),
        ]
          .then { super().define("__Test__.Person", it) }
      end

      it { is_expected.to be_ok }

      describe 'the substitution' do
        subject { super() => Ok(substitution); substitution }

        its(:mappings) { is_expected.to include('t1' => type2) }
      end
    end

    describe 'unifying struct with type params with open record' do
      let(:type1) { Type.anonymous_record({ name: Type.string }, Type.var('t1')) }
      let(:type2) { Type.constructor("__Test__.Person").apply(Type.var('t2')) }

      let(:env) do
        Frontend::TypeChecking::TypeDef[
          "__Test__.Person",
          [Type.var('id')],
          Type.anonymous_record({ name: Type.string, age: Type.int, id: Type.var('id')}, nil),
        ]
          .then { super().define("__Test__.Person", it) }
      end

      it { is_expected.to be_ok }

      describe 'the substitution' do
        subject { super() => Ok(substitution); substitution }

        its(:mappings) { is_expected.to include('t1' => type2) }
      end
    end
  end
end
