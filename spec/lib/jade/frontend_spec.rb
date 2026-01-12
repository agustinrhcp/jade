require 'spec_helper'

require 'jade/symbol'
require 'jade/frontend'
require 'jade/parser'
require 'jade/lexer'
require 'jade/ast'
require 'jade/ast/pretty_printer'

module Jade
  describe Frontend do
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
      its(:symbol) { is_expected.to eql Symbol.type_ref('Basics', 'Int') }

      context 'with a bool' do
        let(:text) do
          <<~JADE
            False
          JADE
        end

        it { is_expected.to be_a(AST::Node).and be_a(AST::Literal) }
        its(:symbol) { is_expected.to eql Symbol.type_ref('Basics', 'Bool') }
      end

      context 'with a string' do
        let(:text) do
          <<~JADE
            "Pepe"
          JADE
        end

        it { is_expected.to be_a(AST::Node).and be_a(AST::Literal) }
        its(:symbol) { is_expected.to eql Symbol.type_ref('String', 'String') }
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

      context 'another case' do
        let(:text) do
          <<~JADE
            1 + 2 * 3
          JADE
        end

        it { is_expected.to be_a(AST::InfixApplication) }

        it 'precedence is respected' do
          expect(AST::PrettyPrinter.print(subject)).to eql "(1 + (2 * 3))"
        end
      end

      context 'inside a function declaration' do
        let(:text) do
          <<~JADE
            def pepe() -> Int
              2 * 2 + 3 * 3
            end
          JADE
        end

        it 'precedence is respected' do
          expect(AST::PrettyPrinter.print(subject.body.expressions.first)).to eql "((2 * 2) + (3 * 3))"
        end
      end
    end

    context 'grouping' do
      include_context "single expression body"

      let(:text) do
        <<~JADE
          (2 + 3)
        JADE
      end

      it { is_expected.to be_a(AST::Grouping) }
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
          symbol = subject.lookup(Symbol.value_ref('__Test__', 'add'))

          expect(symbol).to be_a(Symbol::Function)
          expect(symbol.module_name).to eql '__Test__'
          expect(symbol.params).to include('a' => Symbol::TypeRef['Basics', 'Int'])
          expect(symbol.params).to include('b' => Symbol::TypeRef['Basics', 'Int'])
          expect(symbol.return_type).to eql(Symbol::TypeRef['Basics', 'Int'])
          expect(symbol.name).to eql 'add'
        end
      end
    end

    context 'a function declaration with a type var' do
      let(:text) do
        <<~JADE
          type Maybe(a) = Just(a) | Nothing

          def pepe(maybe: Maybe(Int), default: Int) -> Int
            case maybe
            of Nothing then default
            of Just(x) then x
            end
          end
        JADE
      end

      subject { super().expressions.last }

      it { is_expected.to be_a(AST::FunctionDeclaration) }
    end

    xcontext 'a duped function declaration' do
      let(:text) do
        <<~JADE
          def add(a: Int, b: Int) -> Int
            a
          end

          def add(a: Int, b: Int) -> Int
            a
          end
        JADE
      end

      subject { frontend => Err(errors); errors }

      it { is_expected.to have(1).item }
      its([0]) { is_expected.to be_a(Frontend::SemanticAnalysis::Error::DuplicateFunctionDeclaration) }
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
          .and_then  { Frontend.run(it) }
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

      it { is_expected.to be_a(AST::MemberAccess) }
      its(:symbol) { is_expected.to eql Symbol::ValueRef['String', 'is_empty']}

      context 'when calling a not exposed function' do
        let(:text) do
          <<~JADE
            String.not_exposed_thingy
          JADE
        end

        subject { frontend => Err(errors); errors }

        it { is_expected.to have(1).item }

        describe 'the error' do
          subject { super().first }

          it { is_expected.to be_a Frontend::SymbolResolution::Error::VariableNotFound }
          its(:message) { is_expected.to include 'I cannot find a `String.not_exposed_thingy` variable' }
          its(:causes) { is_expected.to have(1).item.and all(be_a(Frontend::SymbolResolution::Error::ValueNotExposed)) }
        end
      end

      context 'when calling a non existing module' do
        let(:text) do
          <<~JADE
            Strong.is_empty
          JADE
        end

        subject { frontend => Err(errors); errors }

        it { is_expected.to have(1).item }

        describe 'the error' do
          subject { super().first }

          it { is_expected.to be_a Frontend::SymbolResolution::Error::VariableNotFound }
          its(:message) { is_expected.to include 'I cannot find a `Strong.is_empty` variable' }
          its(:causes) { is_expected.to have(1).item.and all(be_a(Frontend::SymbolResolution::Error::ModuleNotFound)) }
        end
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
      its(:symbol) { is_expected.to eql Symbol.type_ref('__Test__', 'Maybe') }

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
          maybe_symbol = subject.lookup(Symbol::TypeRef['__Test__', 'Maybe'])

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
        its(:symbol) { is_expected.to eql Symbol.value_ref('__Test__', 'Just') }
      end

      context 'referencing a constructor that doesn\'t exist' do
        let(:text) do
          <<~JADE
            Lala
          JADE
        end

        subject { frontend => Err(errors); errors }

        it { is_expected.to have(1).item }

        describe 'the error' do
          subject { super().first }
          it { is_expected.to be_a Frontend::SymbolResolution::Error::ConstructorNotFound }
          its(:message) { is_expected.to include 'I cannot find a `Lala` constructor' }
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

      it { is_expected.to be_a(AST::Module) }

      describe 'the registry' do
        subject { frontend => Ok([_, registry]); registry }

        it 'contains the function symbol' do
          symbol = subject.lookup(Symbol.value_ref('Test', 'hello'))

          expect(symbol).to be_a(Symbol::Function)
          expect(symbol.module_name).to eql 'Test'
        end

        describe 'the Test entry' do
          subject { super().modules['Test'] }

          it 'has the right exposed symbols' do
            expect(subject.exposes).to include('hello' => Symbol::ValueRef['Test', 'hello'])
          end
        end
      end

      context 'without expose' do
        let(:text) do
          <<~JADE
            module Test

            def hello(str: String) -> Bool
              String.is_empty(str)
            end
          JADE
        end

        subject { frontend => Err(errors); errors }

        it { is_expected.to have(1).item }
        its([0]) { is_expected.to be_a(Frontend::SemanticAnalysis::Error::MissingExposingClause) }
      end

      context 'exposing a symbol that doesn\'t exist' do
        let(:text) do
          <<~JADE
            module Test exposing (hei)

            def hello(str: String) -> Bool
              String.is_empty(str)
            end
          JADE
        end

        subject { frontend => Err(errors); errors }

        it { is_expected.to have(1).item }
        its([0]) { is_expected.to be_a(Frontend::ForwardDeclaration::Error::ExposedValueNotFound) }

        context 'and the symbol is a type' do
          let(:text) do
            <<~JADE
              module Test exposing (Salutation)

              def hello(str: String) -> Bool
                String.is_empty(str)
              end
            JADE
          end

          subject { frontend => Err(errors); errors }

          it { is_expected.to have(1).item }
          its([0]) { is_expected.to be_a(Frontend::ForwardDeclaration::Error::ExposedTypeNotFound) }
        end
      end
    end

    context 'if then else' do
      include_context "single expression body"

      let(:text) do
        <<~JADE
          if String.is_empty("") then
            1
          else
            2
          end
        JADE
      end

      it { is_expected.to be_a(AST::IfThenElse) }
    end

    context 'case of' do
      include_context "single expression body"

      let(:text) do
        <<~JADE
          case 1
          of 1 then 1
          of _ then 2
          end
        JADE
      end

      it { is_expected.to be_a(AST::CaseOf) }

      context 'var binding' do
        let(:text) do
          <<~JADE
            case 1
            of 1 then 1
            of x then x
            end
          JADE
        end

        it { is_expected.to be_a(AST::CaseOf) }
      end
    end

    context 'case of with constructor' do
      let(:text) do
        <<~JADE
          type Maybe(a) = Just(a) | Nothing

          case Just(1)
          of Nothing then 0
          of Just(x) then x
          end
        JADE
      end

      subject { super().expressions.last }

      it { is_expected.to be_a(AST::CaseOf) }
    end

    describe 'lambda' do
      include_context "single expression body"

      let(:text) do
        <<~JADE
          (a, b) -> { a + b }
        JADE
      end

      it { is_expected.to be_a(AST::Lambda) }
    end

    describe 'function declaration with lambda' do
      let(:text) do
        <<~JADE
          type Maybe = Just(a) | Nothing

          def map(maybe: Maybe(a), fn: a -> b) -> Maybe(b)
            case maybe
            of Just(something) then fn(something)
            of Nothing then maybe
            end
          end
        JADE
      end

      subject { super().expressions.last }

      it { is_expected.to be_a(AST::FunctionDeclaration) }
    end

    describe '|>' do
      include_context "single expression body"

      let(:text) do
        <<~JADE
          1 |> identity()
        JADE
      end

      subject { super().expressions.last }

      it { is_expected.to be_a(AST::FunctionCall) }
    end
  end
end
