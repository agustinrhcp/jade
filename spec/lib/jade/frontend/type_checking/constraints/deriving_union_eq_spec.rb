require 'spec_helper'

require 'jade'

module Jade
  describe 'deriving Eq for a union with concrete payloads' do
    let(:compiler) { TestCompiler.new }

    def compiled(name, decls, expr)
      header = "module #{name} exposing (probe)"
      probe  = "def probe -> List(Bool)\n  #{expr}\nend"

      compiler.require("#{header}\n\n#{decls}\n\n\n#{probe}\n")

      Object.const_get(name).probe
    end

    let(:box) do
      <<~JADE.chomp
        type Box
          = B(Int)
          | S(String)
          | Pair(Int, String)
          | Empty
      JADE
    end

    it 'compares a variant carrying a concrete type' do
      expect(compiled('Boxes', box, '[B(1) == B(1), B(1) == B(2), B(1) == Empty]'))
        .to eql [true, false, false]
    end

    it 'compares variants of different concrete types independently' do
      expect(compiled('Strings', box, '[S("a") == S("a"), S("a") == S("b")]'))
        .to eql [true, false]
    end

    it 'compares a variant carrying several concrete types' do
      expect(compiled('Pairs', box, '[Pair(1, "a") == Pair(1, "a"), Pair(1, "a") == Pair(1, "b")]'))
        .to eql [true, false]
    end

    it 'still compares nullary variants and type-variable payloads' do
      expect(compiled('Mixedy', box, '[Empty == Empty, Just(1) == Just(1), [B(1)] == [B(1)]]'))
        .to eql [true, true, true]
    end

    let(:mixed) { "type Mixed(a)\n  = M(a, Int)\n  | Tagged(String, a)\n  | None" }

    it 'compares a variant mixing a type parameter with a concrete type' do
      expect(compiled('Mixes', mixed, '[M(1, 2) == M(1, 2), M(1, 2) == M(1, 3)]'))
        .to eql [true, false]
    end

    it 'keeps each payload on its own dictionary' do
      expect(compiled('Tags', mixed, '[Tagged("t", 9) == Tagged("t", 9), None == None]'))
        .to eql [true, true]
    end

    context 'a variant-less union standing in for an opaque native' do
      let(:values) do
        <<~JADE
          module Values exposing (kept, same?)

          import Decode exposing (Value)


          def same?(one: Value, other: Value) -> Bool
            one == other
          end


          def kept(all: List(Value), wanted: List(Value)) -> List(Value)
            all |> List.filter((v) -> { List.member?(wanted, v) })
          end
        JADE
      end

      before { compiler.require(values) }

      it 'compares by native equality rather than answering false' do
        expect(Values.same?({ id: 1 }, { id: 1 })).to be true
        expect(Values.same?({ id: 1 }, { id: 2 })).to be false
      end

      it 'carries that equality into List.member?' do
        expect(Values.kept([1, 2, 3], [2, 3])).to eql [2, 3]
      end
    end
  end
end
