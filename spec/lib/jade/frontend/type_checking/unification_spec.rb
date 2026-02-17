require 'spec_helper'

require 'jade'

module Jade
  describe Frontend::TypeChecking::Unification do
    let(:env) { Frontend::TypeChecking::Env.empty(Frontend::TypeChecking::VarGen.new) }
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

    describe 'unifying record literal with open record with type param' do
      let(:type1) { Type.anonymous_record({ id: Type.var('t1') }, Type.var('t2')) }
      let(:type2) { Type.anonymous_record({ name: Type.string, id: Type.int }, nil) }

      it { is_expected.to be_ok }

      describe 'the substitution' do
        subject { super() => Ok(substitution); substitution }

        its(:mappings) { is_expected.to include('t1' => Type.int) }
        its(:mappings) { is_expected.to include('t2' => type2) }
      end
    end

    describe 'unifying two open records' do
      let(:type1) { Type.anonymous_record({ a: Type.int }, Type.var('-t1')) }
      let(:type2) { Type.anonymous_record({ b: Type.string }, Type.var('-t2')) }

      it { is_expected.to be_ok }

      describe 'the substitution' do
        subject { super() => Ok(substitution); substitution }

        its(:mappings) { is_expected.to include('-t1' => Type.anonymous_record({ a: Type.int, b: Type.string }, Type.var('t2'))) }
        its(:mappings) { is_expected.to include('-t2' => Type.anonymous_record({ a: Type.int, b: Type.string }, Type.var('t2'))) }
        its(:mappings) { is_expected.to include('t1' => Type.anonymous_record({ a: Type.int, b: Type.string }, Type.var('t2'))) }
      end
    end

    describe 'unifying struct with open record' do
      let(:type1) { Type.anonymous_record({ name: Type.string }, Type.var('t1')) }
      let(:type2) { Type.constructor("__Test__.Person").apply([]) }

      let(:env) do
        Frontend::TypeChecking::StructDef[
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

    describe 'unifying struct with type params against open record' do
      let(:type1) { Type.anonymous_record({ name: Type.string }, Type.var('t1')) }
      let(:type2) { Type.constructor("__Test__.Person").apply([Type.var('t2')]) }

      let(:env) do
        Frontend::TypeChecking::StructDef[
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
