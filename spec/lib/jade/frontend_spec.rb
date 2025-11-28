require 'spec_helper'

require 'jade/symbol'
require 'jade/frontend'
require 'jade/parser'
require 'jade/lexer'
require 'jade/ast'
require 'jade/ast/pretty_printer'

module Jade
  describe Frontend do
    shared_context "single expression body" do
      subject do
        body = super()
        expect(body).to be_a(AST::Body)
        expect(body.expressions).to have(1).item
        body.expressions.first
      end
    end

    let(:source) do
      Source.new(uri: 'test', text:)
    end

    let(:frontend) do
      Lexer
        .tokenize(source)
        .then { Parser.parse(it) }
        .and_then  { Frontend.run(it) }
    end

    subject { frontend => Ok([node, _]); node }

    context 'literals' do
      include_context "single expression body"

      let(:text) do
        <<~JADE
          42
        JADE
      end

      it { is_expected.to be_a(AST::Node).and be_a(AST::Literal) }
      its(:symbol) { is_expected.to eql Symbol.type_ref('Basics.Int') }

      context 'with a bool' do
        let(:text) do
          <<~JADE
            False
          JADE
        end

        it { is_expected.to be_a(AST::Node).and be_a(AST::Literal) }
        its(:symbol) { is_expected.to eql Symbol.type_ref('Basics.Bool') }
      end

      context 'with a string' do
        let(:text) do
          <<~JADE
            "Pepe"
          JADE
        end

        it { is_expected.to be_a(AST::Node).and be_a(AST::Literal) }
        its(:symbol) { is_expected.to eql Symbol.type_ref('String.String') }
      end
    end

    context 'variable binding' do
      include_context "single expression body"

      let(:text) do
        <<~JADE
          hello = "Hola"
        JADE
      end

      it { is_expected.to be_a(AST::Node).and be_a(AST::VariableBinding) }

      context 'but shadows' do
        let(:text) do
          <<~JADE
            hello = "Hola"
            hello = "Hei"
          JADE
        end

        subject { frontend => Err(errors); errors }

        it { is_expected.to have(1).item }
        its([0]) { is_expected.to be_a(Frontend::SemanticAnalyzer::ShadowingError) }
      end
    end

    context 'variable reference' do
      let(:text) do
        <<~JADE
          hello = "Hola"
          hello
        JADE
      end

      it { is_expected.to be_a(AST::Node).and be_a(AST::Body) }

      context 'but it is not defined' do
        let(:text) do
          <<~JADE
            hello
          JADE
        end

        subject { frontend => Err(errors); errors }

        it { is_expected.to have(1).item }
        its([0]) { is_expected.to be_a(Frontend::SemanticAnalyzer::UndefinedVariable) }
      end
    end

    context 'infix operations' do
      include_context "single expression body"

      let(:text) do
        <<~JADE
          1 + 2 * 3 - 4 / 5
        JADE
      end

      it { is_expected.to be_a(AST::InfixApplication) }

      it 'precedence is respected' do
        expect(AST::PrettyPrinter.print(subject)).to eql "((1 + (2 * 3)) - (4 / 5))"
      end

      context 'other case' do
        let(:text) do
          <<~JADE
            2 * 2 + 3 * 3
          JADE
        end

        it { is_expected.to be_a(AST::InfixApplication) }

        it 'precedence is respected' do
          expect(AST::PrettyPrinter.print(subject)).to eql "((2 * 2) + (3 * 3))"
        end
      end
    end

    context 'a function declaration' do
      include_context "single expression body"

      let(:text) do
        <<~JADE
          def add(a: Int, b: Int) -> Int
            a
          end
        JADE
      end

      it { is_expected.to be_a(AST::FunctionDeclaration) }

      describe 'its symbol' do
        subject { super().symbol }

        it { is_expected.to be_a(Symbol::ValueRef) }
        its(:qualified_name) { is_expected.to eql "__Test__.add" }
      end

      describe 'the registry' do
        subject { frontend => Ok([_, registry]); registry }

        it 'contains the function symbol' do
          symbol = subject.lookup(Symbol::ValueRef['__Test__.add'])

          expect(symbol).to be_a(Symbol::Function)
          expect(symbol.module_name).to eql '__Test__'
          expect(symbol.params).to include('a' => Symbol::TypeRef['Basics.Int'])
          expect(symbol.params).to include('b' => Symbol::TypeRef['Basics.Int'])
          expect(symbol.return_type).to eql(Symbol::TypeRef['Basics.Int'])
          expect(symbol.name).to eql 'add'
        end
      end
    end

    context 'function call' do
      let(:text) do
        <<~JADE
          def add(a: Int, b: Int) -> Int
            a + b
          end

          add(1, 2)
        JADE
      end

      let(:frontend) do
        Lexer
          .tokenize(source)
          .then { Parser.parse(it) }
          .and_then  { Frontend.run_up_to_semantic_analysis(it) }
      end

      it { is_expected.to be_a(AST::Node).and be_a(AST::Body) }

      context 'the body expressions' do
        subject { super().expressions }
        its([0]) { is_expected.to be_a(AST::FunctionDeclaration) }
        its([1]) { is_expected.to be_a(AST::FunctionCall) }
      end
    end

    context 'member access' do
      include_context "single expression body"

      let(:text) do
        <<~JADE
          String.is_empty
        JADE
      end

      let(:frontend) do
        Lexer
          .tokenize(source)
          .then { Parser.parse(it) }
          .and_then  { Frontend.run_up_to_semantic_analysis(it) }
      end

      it { is_expected.to be_a(AST::MemberAccess) }
      its(:symbol) { is_expected.to eql Symbol::ValueRef['String.is_empty']}
    end

    context 'type def' do
      include_context "single expression body"

      let(:text) do
        <<~JADE
          type Maybe(a) = Just(a) | Nothing
        JADE
      end

      it { is_expected.to be_a(AST::TypeDeclaration) }
      its(:symbol) { is_expected.to eql Symbol.type_ref('__Test__.Maybe') }

      describe 'the variants symbols' do
        subject { super().variants.map(&:symbol) }

        it { is_expected.to have(2).items.and all(be_a(Symbol::ValueRef)) }

        it 'references its variants' do
          expect(subject[0].qualified_name).to eql('__Test__.Just')
          expect(subject[1].qualified_name).to eql('__Test__.Nothing')
        end
      end

      describe 'the registry' do
        subject { frontend => Ok([_, registry]); registry }

        it 'contains the function symbol' do
          maybe_symbol = subject.lookup(Symbol::TypeRef['__Test__.Maybe'])

          expect(maybe_symbol).to be_a(Symbol::Union)
          expect(maybe_symbol.type_params).to eql([Symbol.var('a')])
        end
      end
    end

    context 'type def and reference' do
      let(:text) do
        <<~JADE
          type Maybe(a) = Just(a) | Nothing
          Just
        JADE
      end

      it { is_expected.to be_a(AST::Body) }

      describe 'the reference' do
        subject { super().expressions.last }

        it { is_expected.to be_a(AST::ConstructorReference) }
        its(:symbol) { is_expected.to eql Symbol.value_ref('__Test__.Just') }
      end
    end

    context 'module' do
      let(:text) do
        <<~JADE
          module Test exposing (hello)

          def hello(str: String) -> Bool
            String.is_empty(str)
          end
        JADE
      end

      it { is_expected.to be_a(AST::Module) }

      describe 'the registry' do
        subject { frontend => Ok([_, registry]); registry }

        it 'contains the function symbol' do
          symbol = subject.lookup(Symbol::ValueRef['Test.hello'])

          expect(symbol).to be_a(Symbol::Function)
          expect(symbol.module_name).to eql 'Test'
        end
      end
    end
  end
end
