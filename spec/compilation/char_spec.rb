require 'spec_helper'

require 'jade'

module Jade
  describe 'Char' do
    include_context 'with test compiler'

    let(:source) do
      <<~JADE
        module Pepe exposing(is_a, code_of, roundtrip)

        def is_a(c: Char) -> Bool
          c == 'a'
        end

        def code_of(c: Char) -> Int
          Char.to_code(c)
        end

        def roundtrip(c: Char) -> Maybe(Char)
          Char.from_code(Char.to_code(c))
        end
      JADE
    end

    before { test_compiler.require('pepe', source) }

    it 'compares chars' do
      expect(Pepe.is_a.call('a')).to be true
      expect(Pepe.is_a.call('b')).to be false
    end

    it 'converts to code point' do
      expect(Pepe.code_of.call('a')).to eql 97
      expect(Pepe.code_of.call('A')).to eql 65
    end

    it 'roundtrips through code point' do
      expect(Pepe.roundtrip.call('z')).to be_just('z')
    end

    it 'parses a char literal' do
      test_compiler.require('lit', "module Lit exposing(c)\ndef c() -> Char\n  'x'\nend")
      expect(Lit.c.call).to eql 'x'
    end
  end
end
