require 'jade'

require 'jade/codegen/emitter'

module Jade
  describe Codegen::Emitter do
    subject { described_class.emit(ir) }

    context '[:!, false]' do
      let(:ir) { [:!, false] }

      it { is_expected.to eql "!(false)" }
    end

    context '[:and, true, [:and, true, false]]' do
      let(:ir) { [:and, true, [:and, true, [:!, false]]] }

      it { is_expected.to eql "true && true && !(false)" }
    end

    context '[:var, one]' do
      let(:ir) { [:var, 'one'] }

      it { is_expected.to eql "one" }
    end

    context '[:access, [:var, "one"], "salute"]' do
      let(:ir) { [:access, [:var, 'one'], 'salute'] }

      it { is_expected.to eql "one.salute" }
    end

    context '[:access, [:access, [:var, "r"], "address"], "city"]' do
      let(:ir) { [:access, [:access, [:var, 'r'], 'address'], 'city'] }

      it { is_expected.to eql "r.address.city" }
    end

    context '[:and, [:call, ...], [:call, ...]] for record field comparisons' do
      let(:ir) do
        [
          :and,
          [:call, [:impl_arg, 0, '(==)'], [[:access, [:var, 'one'], 'x'], [:access, [:var, 'other'], 'x']]],
          [:call, [:impl_arg, 1, '(==)'], [[:access, [:var, 'one'], 'y'], [:access, [:var, 'other'], 'y']]]
        ]
      end

      it { is_expected.to eql "impl_arg[0]['(==)'].call(one.x, other.x) && impl_arg[1]['(==)'].call(one.y, other.y)" }
    end

    context 'a derived function body' do
      let(:ir) {
        [
          :case,
          [:list, [[:var, "one"], [:var, "other"]]],
          [
            [
              [:list, [[:constructor, "Just", ["l0"]], [:constructor, "Just", ["r0"]]]],
              [[:call, [:impl_arg, 0, "(==)"], [[:var, "l0"], [:var, "r0"]]]]
            ],
            [
              [:list, [[:constructor, "Nothing", []], [:constructor, "Nothing", []]]],
              [true]
            ],
            [[:_], [false]],
          ]
        ]
      }

      it do
        is_expected.to eql(
          "case [one, other]\n" \
          "in [Just(l0), Just(r0)] then impl_arg[0]['(==)'].call(l0, r0)\n" \
          "in [Nothing(), Nothing()] then true\n" \
          "in _ then false\n" \
          "end"
        )
      end
    end
  end
end
