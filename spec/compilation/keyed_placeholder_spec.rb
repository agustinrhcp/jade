require 'spec_helper'

require 'jade'
require 'jade/module_loader'

module Jade
  describe 'placeholders in keyed calls' do
    include_context 'with test compiler'

    before { test_compiler.require(source) }

    let(:source) do
      <<~JADE
        module Shapes exposing (Point(..), declared_order, one_blank, written_order)

        struct Point = {
          x: Int,
          y: Int
        }


        def declared_order -> Point
          make = Point(x: _, y: _)

          make(1)(2)
        end


        def written_order -> Point
          make = Point(y: _, x: _)

          make(1)(2)
        end


        def one_blank(n: Int) -> Point
          make = Point(x: _, y: n)

          make(n + 1)
        end
      JADE
        .strip
    end

    it 'fills the blanks in the order the fields were written' do
      expect(Shapes::Internal.declared_order).to eql Shapes::Point[1, 2]
    end

    it 'follows the written order, not the struct declaration order' do
      expect(Shapes::Internal.written_order).to eql Shapes::Point[2, 1]
    end

    it 'leaves non-placeholder fields bound' do
      expect(Shapes::Internal.one_blank(5)).to eql Shapes::Point[6, 5]
    end
  end

  describe Frontend, 'placeholders in a keyed variant call' do
    let(:source) { Source.new(uri: 'test', text:) }

    let(:text) do
      <<~JADE
        type Shape = Circle(Int) | Rect({ w: Int, h: Int })
        def make -> Shape
          Rect(w: _, h: 2)
        end
      JADE
    end

    subject do
      Lexer
        .tokenize(source)
        .then { Parsing.parse(it, source:) }
        .and_then { |(ast, _)| Frontend.run(ast) } => Err(errors)

      errors
    end

    it { is_expected.to have(1).item }

    its([0]) do
      is_expected.to be_a(Frontend::SemanticAnalysis::Error::PlaceholderNotAllowed)
    end

    it 'says the record literal is what has no hole, and offers the lambda' do
      expect(subject[0].message)
        .to eq('`Rect` carries a record, and a record literal has no ' \
               'placeholder — `w: _` cannot be a hole')
      expect(subject[0].notes.map(&:message))
        .to eql ['write the lambda instead: `(v) -> { Rect(w: v, ...) }`']
    end

    context 'a variant whose arguments are positional' do
      let(:text) do
        <<~JADE
          type Shape = Circle(Int) | Rect(Int, Int)
          def make -> Shape
            Rect(w: _, h: 2)
          end
        JADE
      end

      # `w:` and `h:` are also unknown fields on a positional variant, so
      # the generic path reports three errors for the one mistake.
      it { is_expected.to have(1).item }

      it 'names the situation and the two ways out' do
        expect(subject[0].message)
          .to eq('`Rect` is a union variant; its arguments are positional ' \
                 'and have no names, so `w:` has nothing to refer to')
        expect(subject[0].notes.map(&:message))
          .to eql ['pass them positionally — `Rect(_, x)` — or pipe into the ' \
                   'first argument, which `|>` fills in for you: `|> Rect(x)`']
      end
    end
  end
end
