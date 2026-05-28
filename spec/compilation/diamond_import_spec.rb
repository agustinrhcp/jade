require 'spec_helper'

require 'jade'
require 'jade/module_loader'

module Jade
  describe 'Diamond imports' do
    include_context 'with test compiler'

    let(:events) do
      <<~JADE
        module M.Events exposing (Event(..))

        type Event = Recorded(amount: Int)
      JADE
    end

    let(:middle) do
      <<~JADE
        module M.Middle exposing (foo)

        import M.Events


        def foo -> Int
          0
        end
      JADE
    end

    let(:b) do
      <<~JADE
        module M.B exposing (run)

        import M.Events
        import M.Middle


        def run -> Int
          0
        end
      JADE
    end

    before do
      test_compiler.write('m/events', events)
      test_compiler.write('m/middle', middle)
    end

    it 'compiles a diamond where a primitive type is used in the shared module' do
      test_compiler.require('m/b', b)
      expect(M::B.run).to eql 0
    end

    context 'with import order reversed in B' do
      let(:b) do
        <<~JADE
          module M.B exposing (run)

          import M.Middle
          import M.Events


          def run -> Int
            0
          end
        JADE
      end

      it 'still compiles' do
        test_compiler.require('m/b', b)
        expect(M::B.run).to eql 0
      end
    end
  end
end
