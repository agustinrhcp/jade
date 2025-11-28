require 'spec_helper'

require 'jade/parser'
require 'jade/lexer'
require 'jade/ast'

module Jade
  describe Parser do
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

    let(:parse) { Lexer.tokenize(source).then { Parser.parse(it) } }
    subject { parse => Ok(node); node }

    context 'literals' do
      include_context "single expression body"

      let(:text) do
        <<~JADE
          42
        JADE
      end

      it { is_expected.to be_a(AST::Node).and be_a(AST::Literal) }
      its(:value) { is_expected.to eql 42 }

      context 'with an string literal' do
        let(:text) do
          <<~JADE
            "Hello"
          JADE
        end

        it { is_expected.to be_a(AST::Node).and be_a(AST::Literal) }
        its(:value) { is_expected.to eql "Hello" }
      end

      context 'and it is empty' do
        let(:text) do
          <<~JADE
            ""
          JADE
        end

        it { is_expected.to be_a(AST::Node).and be_a(AST::Literal) }
        its(:value) { is_expected.to eql "" }
      end

      context 'but it is malformed' do
        let(:text) do
          <<~JADE
            "Hello
          JADE
        end

        subject { parse => Err(err); err }

        it { is_expected.to be_kind_of(Parser::Error) }
        its(:message) { is_expected.to include("Unexpected end of input, expected quote") }
      end
    end

    context 'variable binding' do
      include_context "single expression body"

      let(:text) do
        <<~JADE
          forty_two = 42
        JADE
      end

      it { is_expected.to be_a(AST::Node).and be_a(AST::VariableBinding) }
      its(:name) { is_expected.to eql "forty_two" }
      its(:expression) { is_expected.to be_a(AST::Literal) }

      context 'when it is incomplete' do
        let(:text) do
          <<~JADE
            forty_two =
          JADE
        end

        subject { parse => Err(err); err }

        # TODO: [Parser:MultipleErrors]
        it { is_expected.to be_kind_of(Parser::Error) }
        its(:message) { is_expected.to include("expected constant") }
      end

      context 'when it is incomplete with an incomplete string' do
        let(:text) do
          <<~JADE
            forty_two = "Hello
          JADE
        end

        subject { parse => Err(err); err }

        it { is_expected.to be_kind_of(Parser::Error) }
        its(:message) { is_expected.to include("expected quote") }
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

      it { is_expected.to be_a(AST::Node).and be_a(AST::FunctionDeclaration) }
      its(:name) { is_expected.to eql 'add' }
      its(:params) { is_expected.to have(2).items.and all(be_a(AST::FunctionDeclarationParam)) }
      its(:return_type) { is_expected.to be_a(AST::TypeName) }
    end

    context 'operators' do
      include_context "single expression body"

      let(:text) do
        <<~JADE
          12 + 12
        JADE
      end

      it { is_expected.to be_a(AST::Node).and be_a(AST::InfixApplication) }
      its(:left) { is_expected.to be_a(AST::Literal) }
      its(:operator) { is_expected.to be_a(AST::InfixOperator).and have_attributes(value: '+') }
      its(:right) { is_expected.to be_a(AST::Literal) }

      context 'a chain of operators' do
        let(:text) do
          <<~JADE
            1 + 2 * 3 - 4 / 5
          JADE
        end

        it { is_expected.to be_a(AST::Node).and be_a(AST::InfixApplication) }
        its(:left) { is_expected.to be_a(AST::InfixApplication) }
        its(:operator) { is_expected.to be_a(AST::InfixOperator).and have_attributes(value: '/') }
        its(:right) { is_expected.to be_a(AST::Literal).and have_attributes(value: 5) }
      end
    end

    context 'function calls' do
      include_context "single expression body"

      let(:text) do
        <<~JADE
          add(1, 2)
        JADE
      end

      it { is_expected.to be_a(AST::FunctionCall) }
      its(:callee) { is_expected.to be_a(AST::VariableReference).and have_attributes(name: 'add') }
      its(:args) { is_expected.to have(2).items.and all(be_a(AST::Literal)) }

      context 'function callception' do
        let(:text) do
          <<~JADE
            add(add(1, 2), 3)
          JADE
        end

        it { is_expected.to be_a(AST::FunctionCall) }
        its(:callee) { is_expected.to be_a(AST::VariableReference).and have_attributes(name: 'add') }
        its(:args) { is_expected.to have(2).items.and match [an_instance_of(AST::FunctionCall), an_instance_of(AST::Literal)] }
      end

      context 'function call on a constructor' do
        let(:text) do
          <<~JADE
            Just(42)
          JADE
        end

        it { is_expected.to be_a(AST::FunctionCall) }
        its(:callee) { is_expected.to be_a(AST::ConstructorReference).and have_attributes(name: 'Just') }
      end

      context 'function call on a constructor without params' do
        let(:text) do
          <<~JADE
            Nothing()
          JADE
        end

        it { is_expected.to be_a(AST::FunctionCall) }
        its(:callee) { is_expected.to be_a(AST::ConstructorReference).and have_attributes(name: 'Nothing') }
      end
    end

    context 'type def' do
      include_context "single expression body"

      let(:text) do
        <<~JADE
          type Maybe(a) = Just(a) | Nothing
        JADE
      end

      it { is_expected.to be_a(AST::TypeDeclaration) }
      its(:name) { is_expected.to eql 'Maybe' }
      its(:type_params) { is_expected.to have(1).item }
      its(:variants) { is_expected.to have(2).items }

      describe 'variants' do
        subject { super().variants }
        
        its([0]) { is_expected.to be_a(AST::VariantDeclaration).and have_attributes(name: 'Just') }
        its([1]) { is_expected.to be_a(AST::VariantDeclaration).and have_attributes(name: 'Nothing', args: []) }
      end

      context 'a single variant' do
        let(:text) do
          <<~JADE
            type Int = Int
          JADE
        end

        it { is_expected.to be_a(AST::TypeDeclaration) }
        its(:name) { is_expected.to eql 'Int' }
        its(:variants) { is_expected.to have(1).items }
      end
    end

    context 'a constructor reference' do
      include_context "single expression body"

      let(:text) do
        <<~JADE
          Just
        JADE
      end

      it { is_expected.to be_a(AST::ConstructorReference).and have_attributes(name: 'Just') }
    end

    context 'an import declaration' do
      include_context "single expression body"

      let(:text) do
        <<~JADE
          import Maybe
        JADE
      end

      it { is_expected.to be_a(AST::ImportDeclaration).and have_attributes(module_name: 'Maybe') }

      context 'with exposing' do
        let(:text) do
          <<~JADE
            import Maybe exposing (Maybe)
          JADE
        end

        it { is_expected.to be_a(AST::ImportDeclaration).and have_attributes(module_name: 'Maybe') }

        describe 'its exposing' do
          subject { super().exposing }

          it { is_expected.to have(1).item }
          its(:first) { is_expected.to be_a(AST::TypeName).and have_attributes(type: 'Maybe') }
        end
      end
    end

    context 'member access' do
      include_context "single expression body"

      let(:text) do
        <<~JADE
          String.is_empty
        JADE
      end

      it { is_expected.to be_a(AST::MemberAccess) }
      its(:target) { is_expected.to be_a(AST::ConstructorReference).and have_attributes(name: 'String') }
      its(:name) { is_expected.to be_a(AST::VariableReference) }

      describe 'a longer chain' do
        let(:text) do
          <<~JADE
            String.Utils.is_empty
          JADE
        end

        it { is_expected.to be_a(AST::MemberAccess) }
        its(:target) { is_expected.to be_a(AST::MemberAccess) }
        its(:name) { is_expected.to be_a(AST::VariableReference) }
      end
    end

    context 'qualified call' do
      include_context "single expression body"

      let(:text) do
        <<~JADE
          def is_empty(str: String) -> String
            String.is_empty(str)
          end
        JADE
      end

      it { is_expected.to be_a(AST::FunctionDeclaration) }

      describe 'the qualified call' do
        subject do
          super().body.expressions.first
        end

        it { is_expected.to be_a(AST::FunctionCall) }

        describe 'the callee' do
          subject { super().callee }

          it { is_expected.to be_a(AST::MemberAccess) }
        end
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

      it do
        subject
      end
      it { is_expected.to be_a(AST::Module) }
    end
  end
end
