require 'spec_helper'

require 'jade'

module Jade
  module Codegen
    describe Names do
      describe '.local' do
        it 'leaves an ordinary name alone' do
          expect(described_class.local('total')).to eql 'total'
        end

        it 'moves a Ruby keyword out of the way' do
          expect(described_class.local('begin')).to eql 'begin_'
          expect(described_class.local('next')).to eql 'next_'
          expect(described_class.local('alias')).to eql 'alias_'
        end

        # `begin` and `begin_` are both legal Jade names, so the rewrite has
        # to stay injective or two locals collapse into one.
        it 'keeps a name that already looks rewritten distinct' do
          expect(described_class.local('begin_')).to eql 'begin__'
          expect(described_class.local('begin__')).to eql 'begin___'
        end

        it 'leaves an ordinary name that ends in an underscore alone' do
          expect(described_class.local('total_')).to eql 'total_'
        end
      end
    end
  end
end
