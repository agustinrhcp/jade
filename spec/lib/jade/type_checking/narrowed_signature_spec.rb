require 'spec_helper'

require 'jade/frontend'
require 'jade/parsing'
require 'jade/lexer'

module Jade
  describe 'A signature wider than its body' do
    def check(text)
      Source
        .new(uri: 'test', text:)
        .then { |source| Lexer.tokenize(source).then { Parsing.parse(it, source:) } }
        .and_then { |(ast, _)| Frontend.run(ast) }
    end

    def messages(text)
      check(text) => Err(errors)
      errors.map(&:message)
    end

    it 'is an error when the body fixes a type variable' do
      expect(messages(<<~JADE))
        module Test exposing (anything)

        def anything -> a
          Nothing
        end
      JADE
        .to eq ['`anything` says it works for any `a`, but its body only works when `a` is Maybe(b)']
    end

    it 'is an error when the body fixes one inside another type' do
      expect(messages(<<~JADE))
        module Test exposing (wrap)

        def wrap -> Maybe(a)
          Just(1)
        end
      JADE
        .to eq ['`wrap` says it works for any `a`, but its body only works when `a` is Int']
    end

    it 'is an error when the body makes two type variables one' do
      expect(messages(<<~JADE))
        module Test exposing (same)

        def same(x: a, y: b) -> Bool
          x == y
        end
      JADE
        .to eq ['`same` says `a` and `b` can be different types, but its body needs them to be the same']
    end

    it 'accepts a body as general as its signature' do
      expect(check(<<~JADE)).to be_a(Ok)
        module Test exposing (first, equal)

        def first(xs: List(a)) -> Maybe(a)
          List.head(xs)
        end


        def equal(x: a, y: a) -> Bool
          x == y
        end
      JADE
    end
  end
end
