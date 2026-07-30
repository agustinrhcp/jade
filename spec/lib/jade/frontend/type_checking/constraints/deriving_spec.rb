require 'spec_helper'

require 'jade'

using Jade::TypeFactory

module Jade
  module Frontend
    module TypeChecking
      module Constraints
        describe Deriving, '.register' do
          let(:deriver) do
            Module.new do
              def self.supports?(interface) = interface == 'Fake.Showable'

              def self.derive(_constraint, _registry, _entry_name) = Ok[:derived]
            end
          end

          after { Deriving.registered.clear }

          it 'is not derivable before registering' do
            expect(Deriving.derivable?('Fake.Showable')).to be false
          end

          it 'becomes derivable after registering' do
            Deriving.register(deriver)

            expect(Deriving.derivable?('Fake.Showable')).to be true
          end

          it 'dispatches to the registered deriver' do
            Deriving.register(deriver)

            expect(Deriving.derive(Type.constraint('Fake.Showable', Type.int, nil), nil, 'M') { nil })
              .to eql Ok[:derived]
          end

          it 'registers a deriver once' do
            2.times { Deriving.register(deriver) }

            expect(Deriving.registered).to have(1).item
          end

          it 'refuses something that is not a deriver' do
            expect { Deriving.register(Object.new) }
              .to raise_error(ArgumentError, /supports\?, derive/)
          end

          it 'keeps built-ins ahead of registrations' do
            Module.new do
              def self.supports?(_interface) = true

              def self.derive(*) = Ok[:hijacked]
            end
              .then { Deriving.register(it) }

            expect(Deriving.derive(Type.eq(Type.int), Stdlib.load(Registry.new), 'M') { nil })
              .to_not eql Ok[:hijacked]
          end
        end

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
