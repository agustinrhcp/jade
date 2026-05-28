require 'spec_helper'

require 'jade'

module Jade
  describe 'predicate `?` suffix' do
    let(:source) { Source.new(uri: 'm.jd', text:) }

    let(:frontend) do
      Lexer.tokenize(source)
        .then { Parsing.parse(it, source:) }
        .and_then { |(ast, _)| Frontend.run(ast) }
    end

    context 'predicate returning Bool' do
      let(:text) do
        <<~JADE
          module M exposing (positive?)

          def positive?(n: Int) -> Bool
            n > 0
          end
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
          end
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
          end
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
            in [] then True
            else False
            end
          end


          def run(xs: List(Int)) -> Bool
            empty?(xs)
          end
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
            end
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
            end
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
            end
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
            end
          JADE
        end

        include_examples 'a rejected predicate binding'
      end
    end
  end
end
