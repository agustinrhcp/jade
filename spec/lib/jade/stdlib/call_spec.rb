require 'spec_helper'

require 'jade'

module Jade
  module Stdlib
    describe Call do
      describe 'its symbols' do
        subject do
          described_class
            .symbols
            .reject { it.is_a?(Symbol::Implementation) }
            .map(&:name)
        end

        it { is_expected.to include('Call') }
      end

      describe 'the Call union' do
        subject { described_class.symbols.find { it.is_a?(Symbol::Union) } }

        it { is_expected.to have_attributes(name: 'Call', module_name: 'Call') }

        it 'is parameterised over its ok and error arms, like Task' do
          expect(subject.type_params.map(&:name)).to eq(%i[a e])
        end
      end

      describe 'registration' do
        subject { Stdlib.load(Registry.new) }

        it { is_expected.to have_attributes(modules: hash_including('Call')) }

        it 'resolves Call as a type' do
          expect(subject.modules['Call'].lookup_type('Call'))
            .to have_attributes(name: 'Call')
        end
      end

      it 'is auto-imported rather than an opt-in extension' do
        expect(Stdlib::EXTENSIONS).not_to include(described_class)
        expect(described_class.default_imports)
          .to eq([Symbol.type_ref('Call', 'Call')])
      end

      it 'is deliberately neither Mappable nor Chainable' do
        implemented = described_class
          .symbols
          .grep(Symbol::Implementation)
          .map(&:interface_name)

        expect(implemented).not_to include('Mappable', 'Chainable')
      end
    end
  end
end
