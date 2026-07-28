require 'spec_helper'

require 'jade'

module Jade
  describe Compiler::Config do
    subject(:config) { described_class.new }

    describe '#source_root=' do
      it 'takes a root' do
        config.source_root = 'lib'

        expect(config.source_root).to eql 'lib'
      end

      it 'unwraps a one-element list, which is what setup blocks pass' do
        config.source_root = ['lib']

        expect(config.source_root).to eql 'lib'
      end

      it 'refuses more than one rather than dropping the rest' do
        expect { config.source_root = ['lib', 'app'] }
          .to raise_error(ArgumentError, /takes one root, got 2/)
      end
    end
  end
end
