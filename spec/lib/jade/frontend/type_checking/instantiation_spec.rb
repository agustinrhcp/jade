require 'spec_helper'

require 'jade'

using Jade::TypeFactory

module Jade
  module Frontend
    module TypeChecking
      describe Instantiation do
        describe '#apply' do
          it "instantiates a polymorphic identity consistently" do
            a = Type.var(0, "a")

            scheme =
              Scheme.new(
                quantified: [a],
                type: Type.function([a], a),
              )

            fn, _ = described_class.instantiate(scheme, VarGen.new)

            arg = fn.args.first
            ret = fn.return_type

            expect(arg).to eq ret
            expect(arg).to_not eql a
          end

          it "generates fresh variables for each instantiation" do
            a = Type.var(0, "a")

            scheme =
              Scheme.new(
                quantified: [a],
                type: Type.function([a], a),
              )

            var_gen = VarGen.new
            fn1, _ = described_class.instantiate(scheme, var_gen)
            fn2, _ = described_class.instantiate(scheme, var_gen)

            expect(fn1.args.first).not_to eq fn2.args.first
          end
        end

        describe 'constraints' do
          it "instantiates constraint type vars with the same fresh vars as the type" do
            a = Type.var(0, "a")
            constraint = Type.num(a)

            scheme = Scheme.new(
              quantified: [a],
              type: Type.function([a], a),
              constraints: [constraint],
            )

            fn, constraints = described_class.instantiate(scheme, VarGen.new)

            expect(constraints).to have(1).item
            expect(constraints.first.type).to eq fn.args.first
            expect(constraints.first.type).not_to eql a
          end

          it "generates fresh constraint vars independently per instantiation" do
            a = Type.var(0, "a")
            constraint = Type.num(a)

            scheme = Scheme.new(
              quantified: [a],
              type: Type.function([a], a),
              constraints: [constraint],
            )

            var_gen = VarGen.new
            _, constraints1 = described_class.instantiate(scheme, var_gen)
            _, constraints2 = described_class.instantiate(scheme, var_gen)

            expect(constraints1.first.type).not_to eq constraints2.first.type
          end

          it "returns empty constraints when scheme has none" do
            a = Type.var(0, "a")

            scheme = Scheme.new(quantified: [a], type: Type.function([a], a))

            _, constraints = described_class.instantiate(scheme, VarGen.new)

            expect(constraints).to be_empty
          end
        end
      end
    end
  end
end
