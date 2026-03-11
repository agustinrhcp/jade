require 'spec_helper'

require 'jade'

using Jade::TypeFactory

module Jade
  module Frontend
    module TypeChecking
      describe Scheme do
        it 'free vars exclude quantified vars' do
          a = Type.var(1, 'a')
          b = Type.var(2, 'b')
          scheme = Scheme[[a], Type.function([a], b), []]

          expect(scheme.free_vars).to eql [b]
        end
      end

      describe '.generalize' do
        let(:constraints) { [] }
        subject do
          Generalization
            .generalize(env, type, constraints)
        end

        context 'when the env is empty' do
          let(:env) { Env.empty(VarGen.new) }

          let(:a) { Type.var(1, 'a') }
          let(:b) { Type.var(2, 'b') }
          let(:type) { Type.function([a], b) }
          let(:constraints) { [Type.eq(a)] }

          its(:free_vars, 'has no free vars') { is_expected.to be_empty }
          its(:quantified, 'generalizes all unbound vars') { is_expected.to eql [a, b] }
          its(:constraints) { is_expected.to eq constraints }
          its(:type) { is_expected.to eql type }
        end

        context 'when env contains a free variable' do
          let(:a) { Type.var(1, 'a') }
          let(:b) { Type.var(2, 'b') }

          let(:env) do
            Env.empty(VarGen.new)
              .bind(:x, Scheme.mono(a))
          end

          let(:type) { Type.function([a], b) }

          subject { Generalization.generalize(env, type, []) }

          its(:quantified) { is_expected.to eql [b] }
        end

        context 'vars inside constraints are generalized' do
          let(:a) { Type.var(1, 'a') }
          let(:env) { Env.empty(VarGen.new) }

          let(:type) { Type.bool }
          let(:constraints) { [Type.eq(a)] }

          subject { Generalization.generalize(env, type, constraints) }

          its(:quantified) { is_expected.to eql [a] }
        end

        context 'constraints referencing env vars are not generalized' do
          let(:a) { Type.var(1, 'a') }

          let(:env) do
            Env.empty(VarGen.new)
              .bind(:x, Scheme[[], a, []])
          end

          let(:type) { Type.bool }
          let(:constraints) { [Type.eq(a)] }

          subject { Generalization.generalize(env, type, constraints) }

          its(:quantified) { is_expected.to be_empty }
        end
      end
    end
  end
end
