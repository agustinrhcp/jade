require 'spec_helper'

require 'jade'

using Jade::TypeFactory

module Jade
  describe Frontend::TypeChecking::Unification do
    let(:env) { Frontend::TypeChecking::Env.empty(Frontend::TypeChecking::VarGen.new) }
    subject { described_class.unify(type1, type2, env) }

    describe 'unifying variables' do
      let(:type1) { Type.parse('t1') }
      let(:type2) { Type.parse('t2') }

      it { is_expected.to be_ok }

      describe 'the substitution' do
        subject { super() => Ok(substitution); substitution }

        its(:mappings) { is_expected.to include('t1' => Type.var('t2')) }
      end

      context 'unifying two rigid vars' do
        context 'same rigid var' do
          let(:type1) { Type.parse('t1').make_rigid }
          let(:type2) { Type.parse('t1').make_rigid }

          it { is_expected.to be_ok }
        end

        context 'different rigid vars' do
          let(:type1) { Type.parse('t1').make_rigid }
          let(:type2) { Type.parse('t2').make_rigid }

          it { is_expected.to be_error }
        end
      end

      context 'unifying flexible against rigid' do
        let(:type1) { Type.parse('t1') }
        let(:type2) { Type.parse('t2').make_rigid }

        it { is_expected.to be_error }
      end
    end

    describe 'unifying variable with anything else' do
      let(:type1) { Type.parse('t1') }
      let(:type2) { Type.parse('Int') }

      it { is_expected.to be_ok }

      describe 'the substitution' do
        subject { super() => Ok(substitution); substitution }

        its(:mappings) { is_expected.to include('t1' => Type.int) }
      end

      context 'passing the types the other way around' do
        let(:type1) { Type.parse('Int') }
        let(:type2) { Type.parse('t1') }

        it { is_expected.to be_ok }

        describe 'the substitution' do
          subject { super() => Ok(substitution); substitution }

          its(:mappings) { is_expected.to include('t1' => Type.int) }
        end
      end
    end

    describe 'unifying functions' do
      let(:type1) { Type.parse('t1 -> t1') }
      let(:type2) { Type.parse('t2 -> t1') }

      it { is_expected.to be_ok }

      describe 'the substitution' do
        subject { super() => Ok(substitution); substitution }

        its(:mappings) { is_expected.to include('t1' => Type.var('t2')) }
      end

      context 'when the vars are rigid' do
        let(:type1) { Type.parse('t1 -> t1') }
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
      let(:type1) { Type.parse "{ t2 | id: t1 }" }
      let(:type2) { Type.parse "{ name: String, id: Int }" }

      it { is_expected.to be_ok }

      describe 'the substitution' do
        subject { super() => Ok(substitution); substitution }

        its(:mappings) { is_expected.to include('t1' => Type.int) }
        its(:mappings) { is_expected.to include('t2' => type2) }
      end
    end

    describe 'unifying record open record with literal' do
      let(:type1) { Type.parse "{ name: String, id: Int }" }
      let(:type2) { Type.parse "{ t2 | id: t1 }" }

      it { is_expected.to be_ok }

      describe 'the substitution' do
        subject { super() => Ok(substitution); substitution }

        its(:mappings) { is_expected.to include('t1' => Type.int) }
        its(:mappings) { is_expected.to include('t2' => type1) }
      end
    end

    describe 'unifying two open records' do
      let(:type1) { Type.parse "{ a | a: Int }" }
      let(:type2) { Type.parse "{ b | b: String }" }

      it { is_expected.to be_ok }

      describe 'the substitution' do
        subject { super() => Ok(substitution); substitution }

        its(:mappings) { is_expected.to include('a' => Type.parse('{ t1 | a: Int, b: String }')) }
        its(:mappings) { is_expected.to include('b' => Type.parse('{ t1 | a: Int, b: String }')) }
        its(:mappings) { is_expected.to include('t1' => Type.parse('{ t1 | a: Int, b: String }')) }
      end
    end

    describe 'unifying struct with open record' do
      let(:type1) { Type.parse '{ t1 | name: String }' }
      let(:type2) { Type.parse 'Test.Person' }

      let(:env) do
        Frontend::TypeChecking::StructDef[
          "Test.Person",
          [],
          Type.parse("{ name: String, age: Int }"),
        ]
          .then { super().define("Test.Person", it) }
      end

      it { is_expected.to be_ok }

      describe 'the substitution' do
        subject { super() => Ok(substitution); substitution }

        its(:mappings) { is_expected.to include('t1' => type2) }
      end
    end

    describe 'unifying struct with type params against open record' do
      let(:type1) { Type.parse "{ t1 | name: String }"}
      let(:type2) { Type.parse "Test.Person(t2)" }

      let(:env) do
        Frontend::TypeChecking::StructDef[
          "Test.Person",
          [Type.var('id')],
          Type.parse("{ name: String, age: Int, id: id }"),
        ]
          .then { super().define("Test.Person", it) }
      end

      it { is_expected.to be_ok }

      describe 'the substitution' do
        subject { super() => Ok(substitution); substitution }

        its(:mappings) { is_expected.to include('t1' => type2) }
      end
    end

    describe 'unifying lambdas' do
      let(:type1) { Type.parse "t1"}
      let(:type2) { Type.parse "a, a -> Bool" }

      it { is_expected.to be_ok }

      describe 'the substitution' do
        subject { super() => Ok(substitution); substitution }

        its(:mappings) { is_expected.to include('t1' => type2) }
      end
    end
  end
end
