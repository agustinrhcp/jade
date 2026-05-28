require 'spec_helper'

require 'jade/lexer'
require 'jade/parsing'
require 'jade/ast'
require 'jade/frontend/desugaring'

module Jade
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

    context 'a call with no placeholders' do
      let(:text) { "add(1, 2)\n" }

      it { is_expected.to be_a(AST::FunctionCall) }
      its(:args) { is_expected.to all(be_a(AST::Literal)) }
    end

    context 'a call with a single trailing placeholder' do
      let(:text) { "add(1, _)\n" }

      it { is_expected.to be_a(AST::Lambda) }
      its(:params) { is_expected.to have(1).item }

      describe 'the wrapped body' do
        subject { super().body => AST::Body(expressions: [call]); call }

        it { is_expected.to be_a(AST::FunctionCall) }
        its(:args) { is_expected.to match [an_instance_of(AST::Literal), an_instance_of(AST::VariableReference)] }
      end
    end

    context 'a call with a leading placeholder' do
      let(:text) { "add(_, 5)\n" }

      it { is_expected.to be_a(AST::Lambda) }

      describe 'the wrapped body' do
        subject { super().body => AST::Body(expressions: [call]); call }

        its(:args) { is_expected.to match [an_instance_of(AST::VariableReference), an_instance_of(AST::Literal)] }
      end
    end

    context 'a constructor with two placeholders' do
      let(:text) { "Person(_, _)\n" }

      it 'desugars to nested unary lambdas (curried)' do
        expect(subject).to be_a(AST::Lambda)
        expect(subject.params).to have(1).item

        inner_body = subject.body
        expect(inner_body).to be_a(AST::Body)
        inner_lambda = inner_body.expressions.last
        expect(inner_lambda).to be_a(AST::Lambda)
        expect(inner_lambda.params).to have(1).item

        call = inner_lambda.body.expressions.last
        expect(call).to be_a(AST::FunctionCall)
        expect(call.args).to all(be_a(AST::VariableReference))
      end
    end

    context 'a nested call f(g(_))' do
      let(:text) { "f(g(_))\n" }

      it 'binds the placeholder to the innermost call' do
        expect(subject).to be_a(AST::FunctionCall)
        expect(subject.callee).to be_a(AST::VariableReference).and have_attributes(name: 'f')

        inner = subject.args.first
        expect(inner).to be_a(AST::Lambda)
        expect(inner.params).to have(1).item
      end
    end
  end
end
