require 'spec_helper'

require 'jade'

using Jade::TypeFactory

module Jade
  module Frontend
    module TypeChecking
      module Constraints
        describe Deriving::Eq do
          describe '.supports?' do
            subject { described_class.supports?(interface) }

            context 'Eq' do
              let(:interface) { 'Basics.Eq' }

              it { is_expected.to be true }
            end

            context 'Comparable' do
              let(:interface) { 'Basics.Comparable' }

              it { is_expected.to be false }
            end
          end

          describe '.derive' do
            let(:registry) { Stdlib.load(Registry.new) }
            let(:entry_name) { '__Test__' }

            subject { described_class.derive(constraint, registry, entry_name) { Constraints.resolve(it, registry, entry_name) } }

            context 'Eq(Int)' do
              let(:constraint) { Type.eq(Type.int) }

              it { is_expected.to be_ok }

              describe 'the implementation' do
                subject { super() => Ok[impl]; impl }

                it { is_expected.to be_a(Symbol::Implementation) }
                its(:constraints) { is_expected.to be_empty }
                its(:functions) { is_expected.to_not be nil }
                its(:deps) { is_expected.to be_empty }
              end
            end

            context 'Eq(Maybe(Int))' do
              let(:constraint) { Type.eq(Type.maybe(Type.int)) }

              it { is_expected.to be_ok }

              describe 'the implementation' do
                subject { super() => Ok[impl]; impl }

                it { is_expected.to be_a(Symbol::Implementation) }
                its(:constraints) { is_expected.to have(1).items }
                its(:functions) { is_expected.to_not be nil }
                its(:deps) { is_expected.to have(1).items }

                describe 'its constraint' do
                  subject { super().constraints.first }

                  its(:interface) { is_expected.to eql 'Basics.Eq' }
                  its(:type) { is_expected.to eql Type.int }
                end

                describe 'its dep' do
                  subject { super().deps.first }

                  it { is_expected.to be_a(Symbol::Implementation) }
                  its(:interface) { is_expected.to eql Symbol::TypeRef['Basics', 'Eq'] }
                  its(:type) { is_expected.to eql Symbol::TypeRef['Basics', 'Int'] }
                end
              end
            end

            context 'Eq(a -> a)' do
              let(:constraint) do
                Type
                  .eq(Type.parse('a -> a'))
                  .with(origin: AST::FunctionCall.new(callee: nil, args: nil, infix: nil, range: 0..10))
              end

              it { is_expected.to be_error }

              describe 'its error' do
                subject { super() => Err[error]; error }

                it { is_expected.to be_a(Error::DerivationFailed) }
              end
            end
          end
        end
      end
    end
  end
end
