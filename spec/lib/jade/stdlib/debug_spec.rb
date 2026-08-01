require 'spec_helper'

require 'jade'

module Jade
  module Stdlib
    describe Debug do
      let(:compiler) { TestCompiler.new }

      # A fresh module per render: TestCompiler caches by module name, and the
      # generated Ruby constant would otherwise answer for the previous source.
      def render(expr, decls: nil)
        @seq = (@seq || 0) + 1
        name = "DebugProbe#{('A'.ord + @seq - 1).chr}"
        parts = ["module #{name} exposing (probe)", '', 'import Debug']
        parts += ['', '', decls] if decls
        parts += ['', '', "def probe -> String", "  Debug.to_string(#{expr})", 'end']

        compiler.require(name, parts.join("\n") + "\n")
        Object.const_get(name).probe
      end

      it 'renders primitives the way they are written' do
        expect(render('42')).to eql '42'
        expect(render('"hi"')).to eql '"hi"'
        expect(render('True')).to eql 'true'
      end

      it 'renders lists and tuples' do
        expect(render('[1, 2, 3]')).to eql '[1, 2, 3]'
        expect(render('(1, "a")')).to eql '(1, "a")'
      end

      it 'renders stdlib variants by constructor' do
        expect(render('Just(7)')).to eql 'Just(7)'
        expect(render('Nothing')).to eql 'Nothing'
        expect(render('Ok([1])')).to eql 'Ok([1])'
      end

      it 'renders a nullary variant as its bare name' do
        expect(render('Red', decls: "type Colour\n  = Red\n  | Green")).to eql 'Red'
      end

      it 'renders a struct with its field names' do
        expect(render('Point(3, 4)', decls: "struct Point = {\n  x: Int,\n  y: Int\n}"))
          .to eql 'Point { x: 3, y: 4 }'
      end

      it 'renders nesting' do
        expect(render('Just([Ok(1), Err("no")])')).to eql 'Just([Ok(1), Err("no")])'
      end

      describe 'log' do
        def logged(expr)
          @seq = (@seq || 0) + 1
          name = "DebugLog#{('A'.ord + @seq - 1).chr}"
          compiler.require(name, <<~JADE)
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
