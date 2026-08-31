require 'spec_helper'

require 'jade/frontend/pattern_analysis'
require 'jade/frontend/type_checking/env'
require 'jade/frontend/type_checking'
require 'jade/type'

using Jade::TypeFactory

module Jade
  module Frontend
    module PatternAnalysis
      describe Signature do
        let(:env) { TypeChecking::Env.empty }

        describe '.of' do
          subject { described_class.of(type, env) }

          def self.cases(*expected)
            its(:cases) { is_expected.to eql(expected) }
          end

          context 'with Bool' do
            let(:type) { Type.bool }

            cases ConstructorCase['Basics.True', []],
                  ConstructorCase['Basics.False', []]

            its(:total) { is_expected.to be true }
          end

          context 'with a tuple' do
            let(:type) do
              Type.constructor('Tuple.Tuple2').apply([Type.int, Type.bool])
            end

            cases ConstructorCase['Tuple.Tuple2', [Type.int, Type.bool]]

            its(:total) { is_expected.to be true }
          end

          context 'with a list' do
            let(:type) { Type.constructor('List.List').apply([Type.int]) }

            it 'opens a column for the element and one for the tail' do
              expect(subject.cases).to eql([
                ConstructorCase['List.Nil', []],
                ConstructorCase['List.Cons', [Type.int, type]],
              ])
            end

            its(:total) { is_expected.to be true }
          end

          # Nothing enumerates these, so a column of one is narrowed only by
          # the literals the rows happen to name.
          ['Basics.Int', 'Basics.Float', 'String.String'].each do |name|
            context "with #{name}" do
              let(:type) { Type.constructor(name).apply([]) }

              cases

              its(:total) { is_expected.to be false }
            end
          end

          context 'with a type var' do
            let(:type) { Type.var('a') }

            cases

            its(:total) { is_expected.to be false }
          end

          context 'with a union' do
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

            let(:type) { Type.constructor('Maybe.Maybe').apply([Type.bool]) }

            # The payload column is Bool, not `a` — otherwise the columns a
            # constructor opens up cannot be split in turn.
            cases ConstructorCase['Maybe.Just', [Type.bool]],
                  ConstructorCase['Maybe.Nothing', []]

            its(:total) { is_expected.to be true }
          end

          # A type reached through an imported struct's field, or an opaque
          # intrinsic. Any pattern the user can write is trivially exhaustive.
          context 'with a type that has no constructors to see' do
            let(:type) { Type.constructor('Other.Thing').apply([]) }

            cases

            its(:total) { is_expected.to be true }
          end
        end

        describe '.uninhabited?' do
          subject { described_class.uninhabited?(type) }

          context 'with Never' do
            let(:type) { Type.never }

            it { is_expected.to be true }
          end

          context 'with anything else' do
            let(:type) { Type.int }

            it { is_expected.to be false }
          end
        end

        describe '.expandable?' do
          subject { described_class.expandable?(type, env) }

          context 'with a struct' do
            let(:env) do
              TypeChecking::StructDef[
                'Test.Person',
                [],
                Type.parse('{ name: String, age: Int }'),
              ]
                .then { super().define('Test.Person', it) }
            end

            let(:type) { Type.parse('Test.Person') }

            it { is_expected.to be true }

            it 'reads its fields' do
              expect(described_class.fields(type, env).keys)
                .to contain_exactly('name', 'age')
            end
          end

          context 'with a union' do
            let(:type) { Type.bool }

            it { is_expected.to be false }
          end
        end
      end
    end
  end
end
