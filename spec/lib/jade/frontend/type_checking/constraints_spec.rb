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
            type_params: [],
            constraints: [],
            functions: {},
            deps: [],
            extends: [],
            decl_span: nil,
          )
        end

        let(:registry) { Registry.new.add_module(Registry.entry('__Test__').define(impl_sym)) }
        let(:entry_name) { '__Test__' }
        let(:origin) do
          AST::FunctionCall.new(callee: nil, args: [], infix: false, dictionaries: [], range: nil)
        end

        describe '.resolve' do
          context 'when the constraint type is a concrete Application' do
            let(:constraint) { Type.constraint('__Iface__.Eq', Type.int, origin) }

            it 'returns Ok with the implementation' do
              expect(described_class.resolve(constraint, registry, entry_name)).to be_ok
            end
          end

          context 'when no implementation matches and not derivable' do
            let(:constraint) { Type.constraint('__Iface__.Ord', Type.int, origin) }

            it 'returns Err with MissingImplementation' do
              result = described_class.resolve(constraint, registry, entry_name)
              expect(result).to be_error
              result.on_err { |e| expect(e).to be_a(Error::MissingImplementation) }
            end
          end

          context 'when the constraint is a type var' do
            let(:constraint) { Type.constraint('__Iface__.Eq', Type.var('a1', 'a'), origin) }

            it 'returns Err with UnresolvedConstraint' do
              result = described_class.resolve(constraint, registry, entry_name)
              expect(result).to be_error
              result.on_err { |e| expect(e).to be_a(Error::UnresolvedConstraint) }
            end
          end
        end

        describe '.solve_at_call_site' do
          context 'when the constraint is a type var (unresolved)' do
            let(:constraint) { Type.constraint('__Iface__.Eq', Type.var('a1', 'a'), origin) }

            it 'returns no errors (bubbles up)' do
              expect(described_class.solve_at_call_site(constraint, registry, entry_name)).to be_empty
            end
          end

          context 'when no implementation exists' do
            let(:constraint) { Type.constraint('__Iface__.Ord', Type.int, origin) }

            subject { described_class.solve_at_call_site(constraint, registry, entry_name) }

            it { is_expected.to have(1).item }
            its(:first) { is_expected.to be_a(Error::MissingImplementation) }
          end

          context 'when a matching implementation exists' do
            let(:constraint) { Type.constraint('__Iface__.Eq', Type.int, origin, index: 0) }

            subject { described_class.solve_at_call_site(constraint, registry, entry_name) }

            it { is_expected.to be_empty }

            it 'attaches the implementation to the origin dictionaries' do
              described_class.solve_at_call_site(constraint, registry, entry_name)
              expect(origin.dictionaries).not_to be_empty
            end
          end
        end
      end
    end
  end
end
