require 'spec_helper'

require 'jade'

module Jade
  describe 'predicate `?` suffix' do
    let(:source) { Source.new(uri: 'm.jd', text:) }

    let(:frontend) do
      Lexer.tokenize(source)
        .then { Parsing.parse(it, entry: source.uri) }
        .and_then { |(ast, _)| Frontend.run(ast) }
    end

    context 'predicate returning Bool' do
      let(:text) do
        <<~JADE
          module M exposing (positive?)

          def positive?(n: Int) -> Bool
            n > 0
        JADE
      end

      it 'accepts the declaration' do
        expect(frontend).to be_ok
      end
    end

    context 'predicate returning a non-Bool type' do
      let(:text) do
        <<~JADE
          module M exposing (bad?)

          def bad? -> Int
            42
        JADE
      end

      subject { frontend => Err(errors); errors }

      it { is_expected.to have(1).item }
      its([0]) { is_expected.to be_a(Frontend::SemanticAnalysis::Error::PredicateMustReturnBool) }
      its([0]) { is_expected.to have_attributes(message: a_string_including('`bad?`')) }
    end

    context 'non-predicate function returning Bool is unaffected' do
      let(:text) do
        <<~JADE
          module M exposing (positive)

          def positive(n: Int) -> Bool
            n > 0
        JADE
      end

      it 'accepts the declaration without forcing `?`' do
        expect(frontend).to be_ok
      end
    end

    context '`?` inside identifier names' do
      let(:text) do
        <<~JADE
          module M exposing (run)

          def empty?(xs: List(Int)) -> Bool
            case xs
            of [] -> True
            of _ -> False

          def run(xs: List(Int)) -> Bool
            empty?(xs)
        JADE
      end

      it 'lexes `empty?` as an identifier and resolves the call' do
        expect(frontend).to be_ok
      end
    end

    context '`?` is rejected at non-function binding sites' do
      shared_examples 'a rejected predicate binding' do
        subject { frontend => Err(errors); errors }

        it { is_expected.to have(1).item }
        its([0]) { is_expected.to be_a(Frontend::SemanticAnalysis::Error::PredicateNameNotAllowed) }
      end

      context 'variable binding' do
        let(:text) do
          <<~JADE
            module M exposing (f)

            def f -> Bool
              empty? = True

              empty?
          JADE
        end

        include_examples 'a rejected predicate binding'
      end

      context 'function parameter' do
        let(:text) do
          <<~JADE
            module M exposing (f)

            def f(empty?: Bool) -> Bool
              empty?
          JADE
        end

        include_examples 'a rejected predicate binding'
      end

      context 'lambda parameter' do
        let(:text) do
          <<~JADE
            module M exposing (f)

            def f -> (Bool -> Bool)
              (empty?) -> { empty? }
          JADE
        end

        include_examples 'a rejected predicate binding'
      end

      context 'destructuring binding (inside a constructor pattern)' do
        let(:text) do
          <<~JADE
            module M exposing (f)

            def f(m: Maybe(Bool)) -> Bool
              Just(empty?) = m

              empty?
          JADE
        end

        include_examples 'a rejected predicate binding'
      end
    end
  end
end
