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

    # The variant lowers to a record literal, and those take holes now, so
    # the call is a function of the hole. Returning it where a `Shape` is
    # wanted is the only complaint left.
    it { is_expected.to have(1).item }

    its([0]) do
      is_expected.to be_a(Frontend::TypeChecking::Error::TypeMismatch)
    end

    it 'reports the shape it built, not a rule about placeholders' do
      expect(subject[0].message).to match(/a -> b/)
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
          .to eql ['write `Rect(_, x)` positionally, or pipe into the ' \
                   'first argument with `|> Rect(x)`']
      end
    end
  end

  describe 'holes in literals' do
    include_context 'with test compiler'

    before do
      test_compiler.require(<<~JADE.strip)
        module Holes exposing (Shape(..), paired, rect_of, sized, tagged)

        type Shape = Rect(w: Int, h: Int)


        def paired -> (Int, String)
          5 |> (_, "five")
        end


        def sized -> { w: Int, h: Int }
          g = { w: _, h: 2 }
          g(3)
        end


        def rect_of -> Shape
          g = Rect(w: _, h: 4)
          g(6)
        end


        def tagged -> (String, Int)
          swap = (_, 1)
          swap("one")
        end
      JADE
    end

    it 'fills a tuple literal' do
      expect(Holes::Internal.paired).to eql Tuple::Tuple2[5, 'five']
    end

    it 'fills a record literal' do
      expect(Holes::Internal.sized.to_h).to eql({ w: 3, h: 2 })
    end

    it 'fills a keyed variant, which lowers to a record literal' do
      expect(Holes::Internal.rect_of).to eql Holes::Rect[w: 6, h: 4]
    end

    it 'binds the hole as the lambda parameter' do
      expect(Holes::Internal.tagged).to eql Tuple::Tuple2['one', 1]
    end
  end
end
