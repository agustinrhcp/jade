require 'spec_helper'

require 'jade'

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
        end
      end
    end
  end
end
