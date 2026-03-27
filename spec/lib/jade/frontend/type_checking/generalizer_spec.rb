require 'spec_helper'

require 'jade'

using Jade::TypeFactory

module Jade
  module Frontend
    module TypeChecking
      describe Generalizer do
        describe '.generalize' do
          subject { described_class.generalize(env) }

          context 'when env is empty' do
            let(:env) { Env.empty(VarGen.new) }

            it 'returns the env unchanged' do
              is_expected.to eql env
            end
          end

          context 'when env has a non-placeholder binding' do
            let(:env) do
              Type.var('t1', 'a')
                .then { Scheme.mono(it) }
                .then { Env.empty.bind(:x, it) }
            end

            it 'leaves the binding unchanged' do
              expect(subject).to eql env
            end
          end

          context 'when env has a single Placeholder with no constraints' do
            let(:a) { Type.var('t1', 'a') }
            let(:b) { Type.var('t2', 'b') }
            let(:type) { Type.function([a], b) }

            let(:env) do
              Env.empty(VarGen.new).bind(:f, Placeholder[type:, constraints: []])
            end

            it 'converts the Placeholder to a Scheme' do
              expect(subject.bindings[:f]).to be_a Scheme
            end

            it 'quantifies the free type variables' do
              scheme = subject.bindings[:f]
              expect(scheme.quantified).to match_array [a, b]
            end
          end

          context 'when env has multiple Placeholders' do
            let(:a) { Type.var('t1', 'a') }
            let(:b) { Type.var('t2', 'b') }
            let(:c) { Type.var('t3', 'c') }
            let(:d) { Type.var('t4', 'd') }

            let(:env) do
              Env.empty(VarGen.new)
                .bind(:f, Placeholder[type: Type.function([a], b), constraints: []])
                .bind(:g, Placeholder[type: Type.function([c], d), constraints: []])
            end

            it 'generalizes both bindings to Schemes' do
              expect(subject.bindings[:f]).to be_a Scheme
              expect(subject.bindings[:g]).to be_a Scheme
            end

            it 'quantifies vars for each binding independently' do
              expect(subject.bindings[:f].quantified).to match_array [a, b]
              expect(subject.bindings[:g].quantified).to match_array [c, d]
            end
          end
        end
      end
    end
  end
end
