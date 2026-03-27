require 'spec_helper'

require 'jade'

module Jade
  module Frontend
    module TypeChecking
      describe Env do
        include SymbolFactory

        describe '.empty' do
          subject { described_class.empty(VarGen.new) }

          its(:bindings) { is_expected.to be_empty }
        end

        describe ".load" do
          let(:entry_before_stdlib) do
            [
              fn_sym('__Test__', 'id')
                .with(params: { x: var_sym('a') })
                .with(return_type: var_sym('a')),
              fn_sym('__Test__', 'f')
                .with(params: { y: var_sym('a') })
                .with(return_type: var_sym('a')),
              struct_sym('__Test__', 'Void'),
            ].reduce(Registry.entry('__Test__')) { |acc, sym| acc.define(sym) }
          end

          let(:registry) do
            Stdlib
              .load(Registry.new)
              .add_module(entry_before_stdlib)
              .then { Stdlib.apply(it) }
          end

          let(:entry) do
            registry.get(entry_before_stdlib.name)
          end

          subject(:env) { described_class.load(entry, registry) }

          its(:bindings) { is_expected.to include('__Test__.f') }
          its(:bindings) { is_expected.to include('__Test__.id') }
          its(:definitions) { is_expected.to include('__Test__.Void') }

          describe 'id\'s scheme' do
            subject { super().bindings['__Test__.id'] }

            it { is_expected.to be_a(Placeholder) }
            its(:free_vars) { is_expected.to have(1).item.and all(be_a(Type::Var)) }

            describe 'the owned var' do
              subject { super().free_vars.first }
              its(:name) { is_expected.to eql 'a' }
            end
          end

          xit "This is more of a schema test, generalizes the function's free vars" do
            id_scheme = env.bindings.dig("__Test__.id")
            f_scheme  = env.bindings.dig("__Test__.f")

            expect(id_scheme.free_vars.map(&:name)).to include("a")
            expect(f_scheme.free_vars.map(&:name)).to include("a")
            expect(id_scheme.free_vars.first).to_not eql f_scheme.free_vars.first
          end

          xit "does not share type variables between schemes" do
            id_scheme = env.bindings.dig("__Test__.id")
            f_scheme  = env.bindings.dig("__Test__.f")

            expect(id_scheme.quantified.first.id).not_to eq(f_scheme.quantified.first.id)
          end

          xit "instantiates fresh vars per usage" do
            id_scheme  = env.bindings.dig("__Test__.id")
            first_use  = env.lookup('__Test__.id')
            second_use = env.lookup('__Test__.id')

            expect(first_use.args.first.id).not_to eq(second_use.args.first.id)
            expect(first_use.return_type.id).not_to eq(second_use.return_type.id)
          end

          describe 'type definitions' do
            its(:definitions) { is_expected.to include('__Test__.Void') }
            its(:definitions) { is_expected.to include('Maybe.Maybe') }

            describe 'a struct' do
              subject { super().definitions['__Test__.Void'] }

              it { is_expected.to be_a(StructDef) }
            end

            describe 'a type' do
              subject { super().definitions['Maybe.Maybe'] }

              it { is_expected.to be_a(TypeDef) }
            end
          end
        end
      end
    end
  end
end
