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
                constraints: [],
              )

            fn, = described_class.instantiate(scheme, VarGen.new)

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
                constraints: [],
              )

            var_gen = VarGen.new
            fn1, = described_class.instantiate(scheme, var_gen)
            fn2, = described_class.instantiate(scheme, var_gen)

            expect(fn1.args.first).not_to eq fn2.args.first
          end

          it "returns constraints substituted with fresh variables" do
            a = Type.var(0, "a")
            constraint = Type.constraint('Eq', a, nil)

            scheme =
              Scheme.new(
                quantified: [a],
                type: Type.function([a], a),
                constraints: [constraint],
              )

            fn, constraints = described_class.instantiate(scheme, VarGen.new)

            expect(constraints).to have(1).item
            expect(constraints.first.type).to eq fn.args.first
            expect(constraints.first.type).not_to eql a
          end

          it "uses the same fresh variable in type and constraints" do
            a = Type.var(0, "a")
            b = Type.var(1, "b")
            constraint_a = Type.constraint('Eq', a, nil)
            constraint_b = Type.constraint('Ord', b, nil)

            scheme =
              Scheme.new(
                quantified: [a, b],
                type: Type.function([a], b),
                constraints: [constraint_a, constraint_b],
              )

            fn, constraints = described_class.instantiate(scheme, VarGen.new)

            expect(constraints[0].type).to eq fn.args.first
            expect(constraints[1].type).to eq fn.return_type
          end

        end
      end
    end
  end
end
