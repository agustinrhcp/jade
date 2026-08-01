require 'spec_helper'

require 'jade'

module Jade
  describe 'deriving Eq for a union with concrete payloads' do
    let(:compiler) { TestCompiler.new }

    def compiled(name, decls, expr)
      header = "module #{name} exposing (probe)"
      probe  = "def probe -> List(Bool)\n  #{expr}\nend"

      compiler.require(name, "#{header}\n\n#{decls}\n\n\n#{probe}\n")

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

    it 'reports a payload it cannot derive instead of raising through the compiler' do
      decls = <<~JADE.chomp
        type Mixed(a)
          = M(a, Int)
          | None
      JADE

      expect { compiled('Cannot', decls, '[M(1, 2) == M(1, 2)]') }
        .to raise_error(Jade::CompilationError)
    end
  end
end
