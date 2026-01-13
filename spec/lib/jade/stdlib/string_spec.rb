require 'spec_helper'

require 'jade/stdlib/string'

module Jade
  module Stdlib
    describe String do
      describe 'its symbols' do
        subject { described_class.symbols.map(&:name) }

        it { is_expected.to include('String') }
        it { is_expected.to include('is_empty') }
      end

      describe 'its registered functions' do
        describe 'is_empty' do
          it 'registers it and works' do
            expect(Runtime.intr("String.is_empty").call("")).to be true
          end
        end

        describe 'length' do
          it 'registers it and works' do
            expect(Runtime.intr("String.length").call("jade")).to eql 4
          end
        end

        describe 'reverse' do
          it 'registers it and works' do
            expect(Runtime.intr("String.reverse").call("jade")).to eql 'edaj'
          end
        end

        describe 'repeat' do
          it 'registers it and works' do
            expect(Runtime.intr("String.repeat").call("jade", 3)).to eql 'jadejadejade'
          end
        end
      end
    end
  end
end
