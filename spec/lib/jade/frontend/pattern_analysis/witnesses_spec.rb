require 'spec_helper'

require 'jade/frontend/pattern_analysis'
require 'jade/frontend/type_checking/env'
require 'jade/frontend/type_checking'
require 'jade/type'

using Jade::TypeFactory

module Jade
  module Frontend
    module PatternAnalysis
      describe Witnesses do
        describe '.missing' do
          let(:env) { TypeChecking::Env.empty }
          subject { described_class.missing(matrix, env) }

          def self.missing(*expected)
            its(:rows) { is_expected.to contain_exactly(*expected) }
          end

          context 'when empty' do
            let(:matrix) { Matrix[[], [Type.int]] }

            it { is_expected.to be_a Matrix }
            missing [Wildcard[]]
          end

          context 'when has a wildcard' do
            let(:matrix) { Matrix[[[Wildcard[]]], [Type.int]] }

            it { is_expected.to be_a Matrix }
            it { is_expected.to be_empty }
          end

          context 'with a bool column' do
            let(:matrix) do
              Matrix[
                [
                  [Constructor['Basics.False', []]],
                  [Constructor['Basics.True', []]],
                ],
                [Type.bool],
              ]
            end

            it { is_expected.to be_a Matrix }
            it { is_expected.to be_empty }

            context 'with missing values' do
              let(:matrix) do
                Matrix[
                  [
                    [Constructor['Basics.False', []]],
                  ],
                  [Type.bool],
                ]
              end

              it { is_expected.to be_a Matrix }
              missing [Constructor['Basics.True', []]]
            end
          end

          # An Int column is split at every bound its patterns mention, so
          # what is missing is named rather than left as `_`.
          context 'with a non exhaustive literal' do
            let(:matrix) do
              Matrix[[[Literal[1]]], [Type.int]]
            end

            missing [Interval[nil, 0]], [Interval[2, nil]]
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
              Matrix[
                [[
                  Constructor['Maybe.Just', [Literal[1]]]
                ]],
                [Type.parse("Maybe(Int)")],
              ]
            end

            missing [Constructor['Maybe.Just', [Interval[nil, 0]]]],
                    [Constructor['Maybe.Just', [Interval[2, nil]]]],
                    [Constructor['Maybe.Nothing', []]]

            context 'exhaustive on constructor but not on inner' do
              let(:matrix) do
                Matrix[
                  [
                    [Constructor['Maybe.Just', [Literal[1]]]],
                    [Constructor['Maybe.Nothing', []]],
                  ],
                  [Type.parse("Maybe(Int)")],
                ]
              end

              it { is_expected.to be_a Matrix }
              missing [Constructor['Maybe.Just', [Interval[nil, 0]]]],
                      [Constructor['Maybe.Just', [Interval[2, nil]]]]
            end

            context 'exhaustive on constructor and inner' do
              let(:matrix) do
                Matrix[
                  [
                    [Constructor['Maybe.Just', [Literal[1]]]],
                    [Constructor['Maybe.Just', [Literal[2]]]],
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

              let(:matrix) do
                Matrix[
                  [[Constructor['Result.Ok', [Wildcard[]]]]],
                  [Type.constructor('Result.Result').apply([Type.int, Type.never])],
                ]
              end

              it 'is exhaustive with only Ok — Error(Never) is impossible' do
                is_expected.to be_empty
              end
            end

            context 'with a type var' do
              let(:matrix) do
                Matrix[
                  [[
                    Constructor['Maybe.Just', [Wildcard[]]]
                  ]],
                  [Type.parse("Maybe(a)")],
                ]
              end

              missing [Constructor['Maybe.Nothing', []]]
            end

            # A tuple column is expanded through its element types, so the
            # columns after it are still checked against their own.
            context 'with a tuple of two Maybes' do
              let(:tuple) do
                Type
                  .constructor('Tuple.Tuple2')
                  .apply([Type.parse("Maybe(Int)"), Type.parse("Maybe(Int)")])
              end

              let(:just) { Constructor['Maybe.Just', [Wildcard[]]] }
              let(:nothing) { Constructor['Maybe.Nothing', []] }

              def self.tuple_of(left, right)
                [Constructor['Tuple.Tuple2', [left, right]]]
              end

              context 'covering all four combinations' do
                let(:matrix) do
                  Matrix[
                    [
                      [Constructor['Tuple.Tuple2', [just, just]]],
                      [Constructor['Tuple.Tuple2', [just, nothing]]],
                      [Constructor['Tuple.Tuple2', [nothing, just]]],
                      [Constructor['Tuple.Tuple2', [nothing, nothing]]],
                    ],
                    [tuple],
                  ]
                end

                it { is_expected.to be_empty }
              end

              context 'missing one combination' do
                let(:matrix) do
                  Matrix[
                    [
                      [Constructor['Tuple.Tuple2', [just, just]]],
                      [Constructor['Tuple.Tuple2', [just, nothing]]],
                      [Constructor['Tuple.Tuple2', [nothing, just]]],
                    ],
                    [tuple],
                  ]
                end

                its(:rows) do
                  is_expected.to contain_exactly(
                    [Constructor['Tuple.Tuple2', [
                      Constructor['Maybe.Nothing', []],
                      Constructor['Maybe.Nothing', []],
                    ]]],
                  )
                end
              end

              context 'wildcard in the second element' do
                let(:matrix) do
                  Matrix[
                    [
                      [Constructor['Tuple.Tuple2', [just, Wildcard[]]]],
                      [Constructor['Tuple.Tuple2', [nothing, just]]],
                    ],
                    [tuple],
                  ]
                end

                its(:rows) do
                  is_expected.to contain_exactly(
                    [Constructor['Tuple.Tuple2', [
                      Constructor['Maybe.Nothing', []],
                      Constructor['Maybe.Nothing', []],
                    ]]],
                  )
                end
              end
            end
          end

          # Enumerating a recursive union column by column diverges unless a
          # constructor the column never mentions is answered from the rows
          # that would have covered it.
          context 'with a recursive union' do
            let(:tree) { Type.constructor('Tree.Tree').apply([]) }

            let(:env) do
              super()
                .define('Tree.Tree', TypeChecking::TypeDef[
                  'Tree.Tree',
                  [],
                  [
                    TypeChecking::ConstructorDef['Tree.Leaf', 'Tree.Tree', []],
                    TypeChecking::ConstructorDef['Tree.Node', 'Tree.Tree', [tree, tree]],
                  ],
                ])
            end

            let(:matrix) do
              Matrix[
                [[Constructor['Tree.Leaf', []]]],
                [tree],
              ]
            end

            missing [Constructor['Tree.Node', [Wildcard[], Wildcard[]]]]
          end
        end
      end
    end
  end
end
