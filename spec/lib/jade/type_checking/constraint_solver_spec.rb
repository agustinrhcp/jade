require 'spec_helper'

require 'jade'

using Jade::TypeFactory

module Jade
  module Frontend
    describe TypeChecking::ConstraintSolver do

      let(:registry) do
        Stdlib.load(Registry.new)
      end

      let(:env) { TypeChecking::Env.empty }

      subject { described_class.solve(constraint, registry, env) }

      context 'for a concrete type' do
        let(:constraint) { Type.eq(Type.int) }

        its(:errors) { is_expected.to be_empty }
        its(:unsolved) { is_expected.to be_empty }
      end

      context 'for a type var' do
        let(:constraint) { Type.eq(Type.var('a')) }

        its(:errors) { is_expected.to be_empty }
        its(:unsolved) { is_expected.to have(1).item }
      end

      context 'for a function without implementation' do
        let(:constraint) { Type.eq(Type.parse 'a, a -> a') }

        its(:errors) { is_expected.to have(1).item }
        its(:unsolved) { is_expected.to be_empty }
      end

      context 'for a type application' do
        let(:constraint) { Type.eq(Type.parse 'Maybe(a)') }

        its(:errors) { is_expected.to have(1).item }
        its(:unsolved) { is_expected.to be_empty }
      end
    end
  end
end
