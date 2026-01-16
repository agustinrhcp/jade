require 'spec_helper'

module Jade
  describe Frontend::TypeChecking::Unification do
    subject { described_class.unify(type1, type2) }

    describe 'unifying variables' do
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
  end
end
