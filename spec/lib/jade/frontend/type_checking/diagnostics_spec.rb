require 'spec_helper'

require 'jade'
require 'jade/frontend'
require 'jade/parsing'
require 'jade/lexer'
require 'jade/ast'

module Jade
  module Frontend
    describe TypeChecking, 'diagnostics' do
      let(:source) { Source.new(uri: 'test', text:) }

      subject(:errors) do
        Lexer
          .tokenize(source)
          .then { Parsing.parse(it, source:) }
          .and_then { |(ast, _)| Frontend.run(ast) } => Err(errs)

        errs
      end

      context 'piping into a call that already has a placeholder' do
        let(:text) do
          <<~JADE
            type AgeTiers = Open(Int)
            type Plan = Plan(AgeTiers, Int)
            def plan1(t: AgeTiers) -> Plan
              t |> Plan(_, 150)
            end
          JADE
        end

        # The call site, the expression around it, and the body that
        # returns it all met the same failure. Four messages, one mistake.
        it { is_expected.to have(1).item }

        its([0]) { is_expected.to be_a(TypeChecking::Error::FunctionCallTypeMismatch) }

        it 'reports the call site, with letters for the inference ids' do
          expect(errors[0].message)
            .to eq('Function call mismatch, expected (AgeTiers, Int) -> Plan ' \
                   'but found (AgeTiers, a, Int) -> b')
        end

        it 'names the shape and the fix' do
          expect(errors[0].notes.map(&:message))
            .to eql ['a `_` makes this a function of the hole, and the call has ' \
                     'one argument too many for that. If you piped into it, `|>` ' \
                     'already supplies the first argument, so drop the `_`']
        end
      end

      context 'a hole in a call that is not one argument short' do
        let(:text) do
          <<~JADE
            def add(a: Int, b: Int) -> Int
              a + b
            end
            def f -> Int
              add(_, "two")("one")
            end
          JADE
        end

        it 'says nothing about placeholders' do
          expect(errors.flat_map { it.notes.map(&:message) }.join)
            .not_to include('drop the `_`')
        end
      end

      context 'two mistakes that share nothing' do
        let(:text) do
          <<~JADE
            def a -> Int
              "not an int"
            end
            def b -> String
              42
            end
          JADE
        end

        it 'keeps both' do
          expect(errors).to have(2).items
        end
      end

      context 'a message that mentions an inference variable' do
        let(:text) do
          <<~JADE
            type Plan = Plan(Int, Int)
            def f(n: Int) -> Plan
              n |> Plan(_, 1)
            end
          JADE
        end

        it 'never prints an inference id' do
          expect(errors.map(&:message)).to all(satisfy { |m| !m.match?(/t\d+/) })
        end
      end
    end
  end
end
