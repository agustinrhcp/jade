require 'spec_helper'

require 'jade/parser'
require 'jade/lexer'
require 'jade/ast'

module Jade
  describe Parser do
    let(:source) do
      text = <<~JADE
        42
      JADE

      Source.new(uri: 'test', text:)
    end

    let(:parse) { Lexer.tokenize(source).then { Parser.parse(it) } }
    subject { parse => Ok(node); node }

    it { is_expected.to be_a(AST::Node).and be_a(AST::Literal) }
    its(:value) { is_expected.to eql 42 }
  end
end
