require 'spec_helper'

require 'jade'

module Jade
  module Frontend
    module TypeChecking
      describe Loader do
        include SymbolFactory

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

        let(:entry) { registry.get(entry_before_stdlib.name) }

        subject(:env) { described_class.load(entry, registry) }

        describe '.load' do
          its(:entry_name) { is_expected.to eq '__Test__' }
          its(:bindings) { is_expected.to include('__Test__.f') }
          its(:bindings) { is_expected.to include('__Test__.id') }
          its(:definitions) { is_expected.to include('__Test__.Void') }

          describe 'accepting a pre-built env via env: keyword' do
            let(:custom_var_gen) { VarGen.new }

            subject(:env) { described_class.load(entry, registry, env: Env.empty(custom_var_gen)) }

            it 'uses the provided env as the base' do
              expect(env.var_gen).to be custom_var_gen
            end

            its(:entry_name) { is_expected.to eq '__Test__' }
            its(:bindings) { is_expected.to include('__Test__.id') }
          end

          describe "id's binding" do
            subject { super().bindings['__Test__.id'] }

            it { is_expected.to be_a(Placeholder) }
            its(:free_vars) { is_expected.to have(1).item.and all(be_a(Type::Var)) }

            describe 'the owned var' do
              subject { super().free_vars.first }
              its(:name) { is_expected.to eql 'a' }
            end
          end

          describe 'type variable isolation between functions' do
            let(:id_binding) { env.bindings['__Test__.id'] }
            let(:f_binding)  { env.bindings['__Test__.f'] }

            it 'each function has its own free var for a' do
              expect(id_binding.free_vars.map(&:name)).to include('a')
              expect(f_binding.free_vars.map(&:name)).to include('a')
            end

            it 'does not share type variable instances between functions' do
              expect(id_binding.free_vars.first).not_to eql f_binding.free_vars.first
            end
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
