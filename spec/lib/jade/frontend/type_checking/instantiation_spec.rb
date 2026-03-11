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

            fn, constraints = described_class.instantiate(scheme, VarGen.new)

            arg = fn.args.first
            ret = fn.return_type

            expect(arg).to eq ret
            expect(arg).to_not eql a
            expect(constraints).to be_empty
          end

          it "instantiates constraints" do
            a = Type.var(0, "a")

            scheme =
              Scheme.new(
                quantified: [a],
                type: Type.function([a], Type.bool),
                constraints: [Type.eq(a)]
              )

            fn, constraints = described_class.instantiate(scheme, VarGen.new)

            arg = fn.args.first

            expect(constraints).to eq [Type.eq(arg)]
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
            fn1, _ = described_class.instantiate(scheme, var_gen)
            fn2, _ = described_class.instantiate(scheme, var_gen)

            expect(fn1.args.first).not_to eq fn2.args.first
          end
        end
      end
    end
  end
end
