require 'spec_helper'

require 'jade'

module Jade
  module Stdlib
    describe Debug do
      let(:compiler) { TestCompiler.new }

      describe 'log' do
        def logged(expr)
          @seq = (@seq || 0) + 1
          name = "DebugLog#{('A'.ord + @seq - 1).chr}"
          compiler.require(<<~JADE)
            module #{name} exposing (probe)

            import Debug


            def probe -> Int
              #{expr}
            end
          JADE

          Object.const_get(name).probe
        end

        it 'returns its value untouched so it can sit mid-pipeline' do
          expect { expect(logged('Debug.log("n", 41) + 1')).to eql 42 }
            .to output(%r{n: 41}).to_stderr
        end
      end
    end
  end
end
