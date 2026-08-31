require 'spec_helper'

require 'jade/frontend/pattern_analysis'
require 'jade/frontend/type_checking/env'
require 'jade/frontend/type_checking'
require 'jade/type'

using Jade::TypeFactory

module Jade
  module Frontend
    module PatternAnalysis
      describe Usefulness do
        describe '.useful?' do
          let(:above) { [] }
          let(:type) { Type.int }
          let(:env) { TypeChecking::Env.empty }

          subject { described_class.useful?(Matrix[above, [type]], row, env) }

          context 'with nothing above it' do
            let(:row) { [Literal[1]] }

            it { is_expected.to be true }
          end

          context 'under a wildcard' do
            let(:above) { [[Wildcard[]]] }
            let(:row) { [Literal[1]] }

            it { is_expected.to be false }
          end

          context 'with a literal repeated' do
            let(:above) { [[Literal[1]], [Literal[2]]] }

            context 'repeating one of them' do
              let(:row) { [Literal[1]] }

              it { is_expected.to be false }
            end

            context 'naming a new one' do
              let(:row) { [Literal[3]] }

              it { is_expected.to be true }
            end

            context 'opening the column' do
              let(:row) { [Wildcard[]] }

              it { is_expected.to be true }
            end
          end

          context 'over Bool' do
            let(:type) { Type.bool }
            let(:above) do
              [
                [Constructor['Basics.True', []]],
                [Constructor['Basics.False', []]],
              ]
            end

            # Both cases are named, so a wildcard behind them reaches nothing.
            context 'with a wildcard behind both cases' do
              let(:row) { [Wildcard[]] }

              it { is_expected.to be false }
            end

            context 'with only one case named' do
              let(:above) { [[Constructor['Basics.True', []]]] }
              let(:row) { [Wildcard[]] }

              it { is_expected.to be true }
            end
          end

          context 'over Maybe(Int)' do
            let(:type) { Type.parse('Maybe(Int)') }

            let(:env) do
              super()
                .define('Maybe.Maybe', TypeChecking::TypeDef[
                  'Maybe.Maybe',
                  [Type.var('a')],
                  [
                    TypeChecking::ConstructorDef['Maybe.Just', 'Maybe.Maybe', [Type.var('a')]],
                    TypeChecking::ConstructorDef['Maybe.Nothing', 'Maybe.Maybe', []],
                  ],
                ])
            end

            context 'with a constructor repeated' do
              let(:above) { [[Constructor['Maybe.Just', [Wildcard[]]]]] }
              let(:row) { [Constructor['Maybe.Just', [Wildcard[]]]] }

              it { is_expected.to be false }
            end

            context 'with a different constructor' do
              let(:above) { [[Constructor['Maybe.Just', [Wildcard[]]]]] }
              let(:row) { [Constructor['Maybe.Nothing', []]] }

              it { is_expected.to be true }
            end

            # The payload column still has ground the literal left open.
            context 'widening a constructor already narrowed by a literal' do
              let(:above) { [[Constructor['Maybe.Just', [Literal[1]]]]] }
              let(:row) { [Constructor['Maybe.Just', [Wildcard[]]]] }

              it { is_expected.to be true }
            end

            context 'with every case of the payload named' do
              let(:type) { Type.constructor('Maybe.Maybe').apply([Type.bool]) }

              let(:above) do
                [
                  [Constructor['Maybe.Just', [Constructor['Basics.True', []]]]],
                  [Constructor['Maybe.Just', [Constructor['Basics.False', []]]]],
                ]
              end

              let(:row) { [Constructor['Maybe.Just', [Wildcard[]]]] }

              it { is_expected.to be false }
            end

            # Redundancy runs before the type error is reported, so the column
            # type and the pattern can disagree. Deadness needs a proof.
            context 'with a constructor the column type does not have' do
              let(:above) { [[Wildcard[]]] }
              let(:row) { [Constructor['Shape.Circle', []]] }

              it { is_expected.to be true }
            end
          end

          context 'over an uninhabited column' do
            let(:type) { Type.never }
            let(:row) { [Wildcard[]] }

            it { is_expected.to be false }
          end
        end
      end
    end
  end
end
