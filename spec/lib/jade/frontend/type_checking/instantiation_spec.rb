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

            fn = described_class.instantiate(scheme, VarGen.new)

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
            fn1 = described_class.instantiate(scheme, var_gen)
            fn2 = described_class.instantiate(scheme, var_gen)

            expect(fn1.args.first).not_to eq fn2.args.first
          end
        end
      end
    end
  end
end
