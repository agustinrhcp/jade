require 'spec_helper'

require 'jade'
require 'jade/module_loader'

module Jade
  describe 'Thunk (() -> T)' do
    include_context 'with test compiler'

    context 'calling a thunk parameter' do
      let(:source) do
        <<~JADE
          module Thunk exposing (run)

          def run(f: () -> Int) -> Int
            f()
          end
        JADE
      end

      before { test_compiler.require('thunk', source) }

      it 'calls the thunk and returns its value' do
        expect(Thunk::Internal.run(-> { 42 })).to eql 42
      end

      it 'calls the thunk each time run is invoked' do
        counter = 0
        f = -> { counter += 1; counter }
        Thunk::Internal.run(f)
        expect(Thunk::Internal.run(f)).to eql 2
      end
    end

    context 'passing a thunk to choose between two computations' do
      let(:source) do
        <<~JADE
          module Thunk exposing (pick)

          def pick(flag: Bool, a: () -> Int, b: () -> Int) -> Int
            case flag
            in True then a()
            in False then b()
            end
          end
        JADE
      end

      before { test_compiler.require('thunk', source) }

      it 'calls the first thunk when flag is true' do
        expect(Thunk::Internal.pick(true, -> { 1 }, -> { 2 })).to eql 1
      end

      it 'calls the second thunk when flag is false' do
        expect(Thunk::Internal.pick(false, -> { 1 }, -> { 2 })).to eql 2
      end
    end

    context 'returning a thunk result through another function' do
      let(:source) do
        <<~JADE
          module Thunk exposing (double_thunk)

          def apply(f: () -> Int) -> Int
            f()
          end


          def double_thunk(f: () -> Int) -> Int
            apply(f) + apply(f)
          end
        JADE
      end

      before { test_compiler.require('thunk', source) }

      it 'applies the thunk twice and adds the results' do
        expect(Thunk::Internal.double_thunk(-> { 10 })).to eql 20
      end
    end
  end
end
