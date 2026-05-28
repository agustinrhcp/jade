require 'spec_helper'

require 'jade/lexer'
require 'jade/parsing'
require 'jade/ast'
require 'jade/frontend/desugaring'

module Jade
  # Regression: synthesized AST::FunctionCall nodes (from infix-operator and
  # tuple desugaring) must carry the source range in their `range` field —
  # not in some other slot due to positional-constructor drift if the
  # FunctionCall field layout ever changes again.
  describe Frontend::Desugaring do
    let(:source) { Source.new(uri: 'test', text:) }

    subject do
      Lexer
        .tokenize(source)
        .then { Parsing.parse(it, source:) }
        .then { it => Ok([node, _]); node }
        .then { Frontend::Desugaring.desugar(it) }
        .then { it => AST::Body(expressions:); expressions.last }
    end

    context 'infix operator desugars to a FunctionCall' do
      let(:text) { "a + b\n" }

      it { is_expected.to be_a(AST::FunctionCall) }
      its(:range) { is_expected.to be_a(Range) }
      its(:symbol) { is_expected.to be_nil }
      its(:dictionaries) { is_expected.to eq([]) }
    end

    context 'tuple literal desugars to a FunctionCall' do
      let(:text) { "(a, b)\n" }

      it { is_expected.to be_a(AST::FunctionCall) }
      its(:range) { is_expected.to be_a(Range) }
      its(:symbol) { is_expected.to be_nil }
      its(:dictionaries) { is_expected.to eq([]) }
    end
  end
end
