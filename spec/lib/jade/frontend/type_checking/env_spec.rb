require 'spec_helper'

require 'jade'

module Jade
  module Frontend
    module TypeChecking
      describe Env do
        include SymbolFactory

        describe '.empty' do
          subject { described_class.empty }

          its(:bindings) { is_expected.to be_empty }
        end

        describe ".load" do
          let(:var_gen) { VarGen.new }

          let(:entry) do
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

          subject(:env) { described_class.load(entry, Registry.new, var_gen) }

          its(:bindings) { is_expected.to include('__Test__.f') }
          its(:bindings) { is_expected.to include('__Test__.id') }
          its(:definitions) { is_expected.to include('__Test__.Void') }

          describe 'id\'s scheme' do
            subject { super().bindings['__Test__.id'] }

            it { is_expected.to be_a(Scheme) }
            its(:quantified) { is_expected.to have(1).item.and all(be_a(Type::Var)) }

            describe 'the owned var' do
              subject { super().quantified.first }
              its(:name) { is_expected.to eql 'a' }
            end
          end

          it "generalizes the function's free vars" do
            id_scheme = env.lookup("__Test__.id")
            f_scheme  = env.lookup("__Test__.f")

            expect(id_scheme.quantified.map(&:name)).to include("a")
            expect(f_scheme.quantified.map(&:name)).to include("a")
            expect(id_scheme.quantified.first).to_not eql f_scheme.quantified.first
          end

          it "does not share type variables between schemes" do
            id_scheme = env.lookup("__Test__.id")
            f_scheme  = env.lookup("__Test__.f")

            expect(id_scheme.quantified.first.id).not_to eq(f_scheme.quantified.first.id)
          end

          it "instantiates fresh vars per usage" do
            id_scheme = env.lookup("__Test__.id")
            first_use  = Inference::Helpers.instantiate(id_scheme, var_gen)
            second_use = Inference::Helpers.instantiate(id_scheme, var_gen)

            expect(first_use.args.first.id).not_to eq(second_use.args.first.id)
            expect(first_use.return_type.id).not_to eq(second_use.return_type.id)
          end

          describe 'type definitions' do
            subject { super().definitions['__Test__.Void'] }

            it { is_expected.to be_a(TypeDef) }
          end
        end
      end
    end
  end
end
