require 'spec_helper'

require 'jade/frontend/pattern_analysis'
require 'jade/frontend/type_checking/env'
require 'jade/frontend/type_checking'
require 'jade/type'

using Jade::TypeFactory

module Jade
  module Frontend
    module PatternAnalysis
      describe Matrix do
        describe '#missing_patterns' do
          let(:env) { TypeChecking::Env.empty }
          subject { matrix.missing_patterns(env) }

          context 'when empty' do
            let(:matrix) { described_class[[], [Type.int]] }

            it { is_expected.to be_a Matrix }
            it { is_expected.to have(1).item }
            it { is_expected.to include [Wildcard[]] }
          end

          context 'when has a wildcard' do
            let(:matrix) { described_class[[[Wildcard[]]], [Type.int]] }

            it { is_expected.to be_a Matrix }
            it { is_expected.to be_empty }
          end

          context 'with a finite literal' do
            let(:matrix) do
              described_class[
                [
                  [Literal[false, Type.bool]],
                  [Literal[true, Type.bool]],
                ],
                [Type.bool],
              ]
            end

            it { is_expected.to be_a Matrix }
            it { is_expected.to be_empty }

            context 'with missing values' do
              let(:matrix) do
                described_class[
                  [
                    [Literal[false, Type.bool]],
                  ],
                  [Type.bool],
                ]
              end


              it { is_expected.to be_a Matrix }
              it { is_expected.to have(1).item }
              it { is_expected.to include([Literal[true, Type.bool]])}
            end
          end

          context 'with a non exhaustive literal' do
            let(:matrix) do
              described_class[[[Literal[1, Type.int]]], [Type.int]]
            end

            it { is_expected.to have(1).item }
            it { is_expected.to include([Wildcard[]]) }
          end

          context 'with a constructor Maybe(Int)' do
            let(:env) do
              super()
                .define('Maybe.Maybe', TypeChecking::TypeDef[
                  'Maybe.Maybe',
                  [Type.var('a')],
                  [
                    TypeChecking::ConstructorDef['Maybe.Just', 'Maybe.Maybe', [Type.var('a')]],
                    TypeChecking::ConstructorDef['Maybe.Nothing', 'Maybe.Maybe',[]],
                  ],
                ])
            end

            let(:matrix) do
              described_class[
                [[
                  Constructor['Maybe.Just', [Literal[1, Type.int]]]
                ]],
                [Type.parse("Maybe(Int)")],
              ]
            end

            it { is_expected.to have(2).items }
            it { is_expected.to include([Constructor['Maybe.Nothing', []]]) }
            it { is_expected.to include([Constructor['Maybe.Just', [Wildcard[]]]]) }

            context 'exhaustive on constructor but not on inner' do
              let(:matrix) do
                described_class[
                  [
                    [Constructor['Maybe.Just', [Literal[1, Type.int]]]],
                    [Constructor['Maybe.Nothing', []]],
                  ],
                  [Type.parse("Maybe(Int)")],
                ]
              end

              it { is_expected.to be_a Matrix }
              it { is_expected.to have(1).item }
              it { is_expected.to include([Constructor['Maybe.Just', [Wildcard[]]]]) }
            end

            context 'exhaustive on constructor and inner' do
              let(:matrix) do
                described_class[
                  [
                    [Constructor['Maybe.Just', [Literal[1, Type.int]]]],
                    [Constructor['Maybe.Just', [Literal[2, Type.int]]]],
                    [Constructor['Maybe.Just', [Wildcard[]]]],
                    [Constructor['Maybe.Nothing', []]],
                  ],
                  [Type.parse("Maybe(Int)")],
                ]
              end

              it { is_expected.to be_a Matrix }
              it { is_expected.to be_empty }
            end

            context 'with Never as a type argument (Result(Int, Never))' do
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
                .define('Result.Result', TypeChecking::TypeDef[
                  'Result.Result',
                  [Type.var('a', 'a'), Type.var('e', 'e')],
                  [
                    TypeChecking::ConstructorDef['Result.Ok', 'Result.Result', [Type.var('a', 'a')]],
                    TypeChecking::ConstructorDef['Result.Error', 'Result.Result', [Type.var('e', 'e')]],
                  ],
                ])
                .define('Basics.Never', TypeChecking::TypeDef['Basics.Never', [], []])
            end

            let(:result_int_never) { Type.constructor('Result.Result').apply([Type.int, Type.never]) }

            let(:matrix) do
              described_class[
                [[Constructor['Result.Ok', [Wildcard[]]]]],
                [result_int_never],
              ]
            end

            it 'is exhaustive with only Ok — Error(Never) is impossible' do
              is_expected.to be_empty
            end
          end

          context 'with a type var' do
              let(:matrix) do
                described_class[
                  [[
                    Constructor['Maybe.Just', [Wildcard[]]]
                  ]],
                  [Type.parse("Maybe(a)")],
                ]
              end

              it { is_expected.to have(1).items }
              it { is_expected.to include([Constructor['Maybe.Nothing', []]]) }
            end
          end
        end
      end
    end
  end
end
