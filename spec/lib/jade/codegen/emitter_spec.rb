require 'tmpdir'
require 'fileutils'

require 'jade'
require 'jade/module_loader'

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

    context '[:impl_dict, 0]' do
      let(:ir) { [:impl_dict, 0] }

      it { is_expected.to eql "impl_arg[0]" }
    end

    describe 'calling a jade function from a derived body' do
      subject { described_class.emit(ir, registry) }

      let(:root) { Dir.mktmpdir('emitter-spec') }

      let(:registry) do
        File.write(File.join(root, 'probe.jd'), <<~JADE)
          module Probe exposing (plain)

          interface Tag(a) with
            tag : a -> String
          end


          def plain(n: Int) -> Int
            n
          end


          def tagged(x: a) -> String
            tag(x)
          end
        JADE

        ModuleLoader.load(root, 'probe.jd', tolerant: true)
      end

      after { FileUtils.remove_entry(root) }

      context 'an unconstrained function' do
        let(:ir) { [:fn, 'Probe.plain'] }

        it { is_expected.to eql "::Probe::Internal.method(:plain)" }
      end

      context 'a constrained one, handed the dictionary it takes' do
        let(:ir) { [:fn, 'Probe.tagged', [0]] }

        it do
          is_expected.to eql(
            "->(*args) { ::Probe::Internal.__tagged__impl__(*args, impl_arg[0]) }"
          )
        end
      end

      context 'a constrained one with no dictionary' do
        let(:ir) { [:fn, 'Probe.tagged'] }

        it { expect { subject }.to raise_error(/takes 1 dictionary, 0 given/) }
      end

      context 'more dictionaries than the callee takes' do
        let(:ir) { [:fn, 'Probe.plain', [0]] }

        it { expect { subject }.to raise_error(/takes 0 dictionaries, 1 given/) }
      end

      context 'with no registry to resolve against' do
        subject { described_class.emit(ir) }

        let(:ir) { [:fn, 'Probe.plain'] }

        it { expect { subject }.to raise_error(/needs a registry/) }
      end
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
          "in [::Just(l0), ::Just(r0)] then impl_arg[0]['(==)'].call(l0, r0)\n" \
          "in [::Nothing(), ::Nothing()] then true\n" \
          "in _ then false\n" \
          "end"
        )
      end
    end
  end
end
