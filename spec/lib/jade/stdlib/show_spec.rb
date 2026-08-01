require 'spec_helper'

require 'jade'

module Jade
  module Stdlib
    describe Show do
      let(:compiler) { TestCompiler.new }

      def shown(expr)
        @seq = (@seq || 0) + 1
        name = "ShowProbe#{('A'.ord + @seq - 1).chr}"
        compiler.require(name, <<~JADE)
          module #{name} exposing (probe)

          import Show exposing (show)


          def probe -> String
            show(#{expr})
          end
        JADE

        Object.const_get(name).probe
      end

      it 'renders primitives as Jade writes them' do
        expect(shown('42')).to eql '42'
        expect(shown('3.5')).to eql '3.5'
        expect(shown('True')).to eql 'true'
        expect(shown('"hi"')).to eql '"hi"'
      end

      it 'refuses to show a function' do
        expect { shown('identity') }.to raise_error(Jade::CompilationError)
      end
    end
  end
end
