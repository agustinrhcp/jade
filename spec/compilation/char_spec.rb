require 'spec_helper'

require 'jade'

module Jade
  describe 'Char' do
    include_context 'with test compiler'

    let(:source) do
      <<~JADE
        module Pepe exposing (code_of, is_a, roundtrip)

        def is_a(c: Char) -> Bool
          c == 'a'


        def code_of(c: Char) -> Int
          Char.to_code(c)


        def roundtrip(c: Char) -> Maybe(Char)
          Char.from_code(Char.to_code(c))
      JADE
    end

    before { test_compiler.require('pepe', source) }

    it 'compares chars' do
      expect(Pepe::Internal.is_a('a')).to be true
      expect(Pepe::Internal.is_a('b')).to be false
    end

    it 'converts to code point' do
      expect(Pepe::Internal.code_of('a')).to eql 97
      expect(Pepe::Internal.code_of('A')).to eql 65
    end

    it 'roundtrips through code point' do
      expect(Pepe::Internal.roundtrip('z')).to be_just('z')
    end

    it 'parses a char literal' do
      test_compiler.require('lit', "module Lit exposing (c)\n\ndef c -> Char\n  'x'\n")
      expect(Lit::Internal.c).to eql 'x'
    end
  end
end
