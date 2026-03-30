require 'spec_helper'

require 'jade'

module Jade
  module Frontend
    module TypeChecking
      describe Constraints do
        let(:impl_sym) do
          Symbol::Implementation.new(
            module_name: '__Test__',
            interface: Symbol::TypeRef['__Iface__', 'Eq'],
            type: Symbol::TypeRef['Basics', 'Int'],
            functions: [],
            decl_span: nil,
          )
        end

        let(:entry) { Registry.entry('__Test__').define(impl_sym) }
        let(:registry) { Registry.new.add_module(entry) }
        let(:entry_name) { '__Test__' }

        describe '.lookup' do
          let(:impl_sym) do
            Symbol::Implementation.new(
              module_name: '__Test__',
              interface: Symbol::TypeRef['__Iface__', 'Eq'],
              type: Symbol::TypeRef['Basics', 'Int'],
              functions: [],
              decl_span: nil,
            )
          end

          let(:entry) { Registry.entry('__Test__').define(impl_sym) }

          let(:registry) { Registry.new.add_module(entry) }

          context 'when the constraint type is a concrete Application' do
            let(:constraint) { Type.constraint('__Iface__.Eq', Type.int, nil) }

            it 'returns the matching implementation' do
              expect(described_class.lookup(constraint, registry)).to be_a(Symbol::Implementation)
            end
          end

          context 'when no implementation matches' do
            let(:constraint) { Type.constraint('__Iface__.Ord', Type.int, nil) }

            it 'returns nil' do
              expect(described_class.lookup(constraint, registry)).to be_nil
            end
          end
        end

        describe '.solve' do
          let(:origin) do
            AST::FunctionCall.new(callee: nil, args: [], infix: false, dictionaries: [], range: nil)
          end

          context 'when the constraint is a type var (unresolved)' do
            let(:constraint) { Type.constraint('__Iface__.Eq', Type.var('a1', 'a'), origin) }

            subject { described_class.solve(constraint, registry, entry_name) }

            it { is_expected.to have(1).item }
            its(:first) { is_expected.to be_a(Error::UnresolvedConstraint) }
          end

          context 'when no implementation exists' do
            let(:constraint) { Type.constraint('__Iface__.Ord', Type.int, origin) }

            subject { described_class.solve(constraint, registry, entry_name) }

            it { is_expected.to have(1).item }
            its(:first) { is_expected.to be_a(Error::MissingImplementation) }
          end

          context 'when a matching implementation exists' do
            let(:constraint) { Type.constraint('__Iface__.Eq', Type.int, origin) }

            subject { described_class.solve(constraint, registry, entry_name) }

            it { is_expected.to be_empty }

            it 'attaches the implementation to the origin dictionaries' do
              described_class.solve(constraint, registry, entry_name)
              expect(origin.dictionaries).not_to be_empty
            end
          end
        end
      end
    end
  end
end
