require 'spec_helper'

require 'jade'
require 'jade/lexer'
require 'jade/parsing'

module Jade
  # Parentheses around a comma list are a tuple, everywhere. A parameter list
  # is bare, and a nested function keeps parentheses of its own, which the
  # arrow inside them tells apart from a tuple.
  describe 'a written function type' do
    include_context 'with test compiler'

    let(:adder) do
      <<~JADE
        def add(a: Int, b: Int) -> Int
          a + b
        end
      JADE
    end

    def compile(body)
      test_compiler.require(<<~JADE)
        module Fn exposing (run)

        #{adder.strip}


        #{body.strip}
      JADE
    end

    it 'takes two arguments when the list is bare' do
      compile(<<~JADE)
        def twice(f: Int, Int -> Int) -> Int
          f(1, 2)
        end


        def run -> Int
          twice(add)
        end
      JADE

      expect(Fn::Internal.run).to eq 3
    end

    it 'takes one tuple when the list is parenthesised' do
      compile(<<~JADE)
        def paired(f: (Int, Int) -> Int) -> Int
          f((1, 2))
        end


        def sum(p: (Int, Int)) -> Int
          (a, b) = p
          a + b
        end


        def run -> Int
          paired(sum)
        end
      JADE

      expect(Fn::Internal.run).to eq 3
    end

    # The two spellings below are not what the formatter writes, so they are
    # asserted at the parser rather than through a fixture it would rewrite.
    describe 'spellings the formatter normalises away' do
      def params_of(text)
        Source.new(uri: 'test', text:).then do |source|
          Lexer.tokenize(source)
            .then { Parsing.parse(it, source:) }
            .then { it => Ok([node, _]); node }
            .body
            .expressions
            .first
            .params
            .first
            .type
            .params
        end
      end

      # The arrow inside the parentheses is what separates the two readings.
      it 'reads a nested two-argument function by the arrow inside it' do
        expect(params_of(<<~JADE).length).to eq 2
          module Fn exposing (run)

          def apply_to(f: (Int, Int -> Int), x: Int) -> Int
            f(x, x)
          end
        JADE
      end

      it 'reads one argument in parentheses, which used to be a parse error' do
        expect(params_of(<<~JADE)).to match [AST::TypeApplication]
          module Fn exposing (run)

          def once(f: (Int) -> Int, x: Int) -> Int
            f(x)
          end
        JADE
      end
    end
  end
end
