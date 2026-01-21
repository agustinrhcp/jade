require 'spec_helper'

require 'jade'

module Jade
  module Frontend
    module TypeChecking
      describe Scheme do
        it 'free vars exclude quantified vars' do
          a = Type.var(1, 'a')
          b = Type.var(2, 'b')
          scheme = Scheme[[a], Type.function([a], b)]

          expect(scheme.free_vars).to eql [b]
        end
      end

      describe '.generalize' do
        subject { Generalization.generalize(env, type) }

        context 'when the env is empty' do
          let(:env) { Env.empty }
          let(:a) { Type.var(1, 'a') }
          let(:b) { Type.var(2, 'b') }
          let(:type) { Type.function([a], b) }

          its(:free_vars, 'has no free vars') { is_expected.to be_empty }
          its(:quantified, 'generalizes all unbound vars') { is_expected.to eql [a, b] }
        end
      end
    end
  end
end
