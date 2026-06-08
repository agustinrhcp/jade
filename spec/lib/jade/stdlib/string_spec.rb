require 'spec_helper'

require 'jade'

module Jade
  module Stdlib
    describe String do
      describe 'its symbols' do
        subject do
          described_class
            .symbols
            .reject { it.is_a?(Symbol::Implementation) }
            .map(&:name)
        end

        it { is_expected.to include('String') }
        it { is_expected.to include('empty?') }
      end

      describe 'its registered functions' do
        describe 'empty?' do
          it 'registers it and works' do
            expect(Runtime.intr("String.empty?").call("")).to be true
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

        describe 'indexes' do
          it 'returns every start position of the substring' do
            expect(Runtime.intr("String.indexes").call("a|b|c|d|e", "|")).to eql [1, 3, 5, 7]
          end

          it 'returns an empty list when the substring is absent' do
            expect(Runtime.intr("String.indexes").call("nope", "|")).to eql []
          end

          it 'returns a single position when the substring appears once' do
            expect(Runtime.intr("String.indexes").call("a|b", "|")).to eql [1]
          end

          it 'returns an empty list for an empty substring' do
            expect(Runtime.intr("String.indexes").call("aaa", "")).to eql []
          end

          it 'reports overlapping matches' do
            expect(Runtime.intr("String.indexes").call("aaaa", "aa")).to eql [0, 1, 2]
          end
        end

        describe 'slice' do
          it 'returns the half-open [from, to) range' do
            expect(Runtime.intr("String.slice").call("abcdef", 0, 3)).to eql 'abc'
          end

          it 'counts a negative end from the string length' do
            expect(Runtime.intr("String.slice").call("abcdef", 2, -1)).to eql 'cde'
          end

          it 'counts a negative start from the string length' do
            expect(Runtime.intr("String.slice").call("abcdef", -3, -1)).to eql 'de'
          end

          it 'clamps an out-of-range end' do
            expect(Runtime.intr("String.slice").call("abcdef", 4, 100)).to eql 'ef'
          end

          it 'returns an empty string when from is not before to' do
            expect(Runtime.intr("String.slice").call("abcdef", 3, 3)).to eql ''
          end
        end
      end
    end
  end
end
