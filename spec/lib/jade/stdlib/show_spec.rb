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

      it 'shows a function as a placeholder rather than refusing' do
        expect(shown('identity')).to eql '<function>'
      end
    end

    describe 'derived' do
      let(:compiler) { TestCompiler.new }

      def derived(name, decls, expr)
        header = "module #{name} exposing (probe)"
        probe  = "def probe -> String\n  show(#{expr})\nend"
        import = 'import Show exposing (show)'

        compiler.require(name, "#{header}\n\n#{import}\n\n\n#{decls}\n\n\n#{probe}\n")

        Object.const_get(name).probe
      end

      let(:box) do
        "type Box\n  = B(Int)\n  | Pair(Int, String)\n  | Empty"
      end

      it 'renders a nullary variant as its bare name' do
        expect(derived('ShowNullary', box, 'Empty')).to eql 'Empty'
      end

      it 'renders a variant carrying concrete types' do
        expect(derived('ShowConcrete', box, 'B(2)')).to eql 'B(2)'
        expect(derived('ShowMulti', box, 'Pair(1, "a")')).to eql 'Pair(1, "a")'
      end

      it 'renders a struct with its field names' do
        expect(derived('ShowStruct', "struct Point = {\n  x: Int,\n  y: Int\n}", 'Point(3, 4)'))
          .to eql 'Point { x: 3, y: 4 }'
      end

      it 'renders stdlib unions through their type-variable payload' do
        expect(derived('ShowJust', box, 'Just(7)')).to eql 'Just(7)'
        expect(derived('ShowNothing', box, 'Nothing')).to eql 'Nothing'
        expect(derived('ShowOk', box, 'Ok(1)')).to eql 'Ok(1)'
      end

      it 'renders nesting' do
        expect(derived('ShowNested', box, 'Just(B(2))')).to eql 'Just(B(2))'
      end
    end
  end
end
