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
          expect(symbol.params['a']).to be_an_int_symbol
          expect(symbol.params['b']).to be_an_int_symbol
          expect(symbol.return_type).to be_an_int_symbol
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

    context 'qualified access' do
      include_context "single expression body"

      let(:text) do
        <<~JADE
          String.is_empty
        JADE
      end

      it { is_expected.to be_a(AST::QualifiedAccess) }
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
          expect(maybe_symbol.type_params.first).to be_a(Symbol::Variable).and have_attributes(name: 'a')
        end
      end

      context 'with unbound vars' do
        let(:text) do
          <<~JADE
            type Unbound(b) = Bound(a)
          JADE
        end

        subject { frontend => Err(errors); errors }

        it { is_expected.to have(1).item }

        describe 'the error' do
          subject { super().first }

          it { is_expected.to be_a Frontend::SemanticAnalysis::Error::UnboundTypeVariable}
          its(:message) { is_expected.to include 'Type `Unbound` has unbound variables `a`' }
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
            expect(subject.exposes).to include(Symbol::ValueRef['Test', 'hello'])
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

      context 'record pattern' do
        let(:text) do
          <<~JADE
            case { name: "Pepe" }
            of { name: name } then name
            end
          JADE
        end

        it { is_expected.to be_a(AST::CaseOf) }
      end

      context 'record pattern mismatch String to Maybe(String)' do
        let(:text) do
          <<~JADE
            case { name: "Pepe" }
            of { name: Just(name) } then name
            end
          JADE
        end

        subject { frontend => Err(errors); errors }

        it { is_expected.to have(2).item }
        its([0]) { is_expected.to be_a(Frontend::TypeChecking::Error::PatternTypeMismatch) }
        its([1]) { is_expected.to be_a(Frontend::TypeChecking::Error::MissingPatterns) }
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
          type Maybe(a) = Just(a) | Nothing

          def map(maybe: Maybe(a), fn: a -> b) -> Maybe(b)
            case maybe
            of Just(something) then Just(fn(something))
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

    describe 'import declaration' do
      let(:text) do
        <<~JADE
          module Imported exposing(MyType, my_function)

          type MyType = MyType | SomeOtherType(String)

          def my_function(thing: MyType) -> String
            case thing
            of MyType then "My type"
            of SomeOtherType(some_other) then some_other
            end
          end
        JADE
      end

      it { is_expected.to be_a AST::Module }

      describe 'its exposed' do
        subject { frontend => Ok([_, registry]); registry.modules['Imported'].exposes }

        it { is_expected.to include Symbol.type_ref('Imported', 'MyType') }
        it { is_expected.to_not include Symbol.value_ref('Imported', 'MyType') }
      end

      context 'when exposing constructors' do
        let(:text) do
          <<~JADE
            module Imported exposing(MyType(..), my_function)

            type MyType = MyType | SomeOtherType(String)

            def my_function(thing: MyType) -> String
              case thing
              of MyType then "My type"
              of SomeOtherType(some_other) then some_other
              end
            end
          JADE
        end

        describe 'is exposed' do
          subject { frontend => Ok([_, registry]); registry.modules['Imported'].exposes }

          it { is_expected.to include Symbol.type_ref('Imported', 'MyType') }
          it { is_expected.to include Symbol.value_ref('Imported', 'MyType') }
        end
      end
    end

    describe 'list' do
      include_context "single expression body"

      let(:text) do
        <<~JADE
          [12, 42]
        JADE
      end

      it { is_expected.to be_a AST::List }
      its(:items) { is_expected.to all(be_a(AST::Literal)) }

      context 'when types of items mismatch' do
        let(:text) do
          <<~JADE
            [12, "String"]
          JADE
        end

        subject { frontend => Err(errors); errors }

        it { is_expected.to have(1).item }
        its([0]) { is_expected.to be_a(Frontend::TypeChecking::Error::ListItemTypeMismatch) }

        describe 'its message' do
          subject { super().first.message }

          it { is_expected.to eql "The item at 2 does not match the previous items in the list, expected Int but found String" }
        end
      end
    end

    describe 'record literal' do
      include_context "single expression body"

      let(:text) do
        <<~JADE
          { a: "hello", b: 42 }
        JADE
      end

      it { is_expected.to be_a(AST::RecordLiteral) }

      context 'with duplicate keys' do
        let(:text) do
          <<~JADE
            { a: "hello", a: 42 }
          JADE
        end

        subject { frontend => Err(errors); errors }

        it { is_expected.to have(1).item }
        its([0]) { is_expected.to be_a(Frontend::SemanticAnalysis::Error::DuplicateRecordField) }
      end
    end

    describe 'a function with open record' do
      include_context "single expression body"

      let(:text) do
        <<~JADE
          def name(thing: { a | name : String }) -> String
            thing.name
          end
        JADE
      end

      it { is_expected.to be_a(AST::FunctionDeclaration) }
    end

    describe 'record update' do
      subject { super().expressions.last }

      let(:text) do
        <<~JADE
          a = { a: 0, b: 0 }
          { a | b: 42 }
        JADE
      end

      it { is_expected.to be_a(AST::RecordUpdate) }

      context 'with sugar on top' do
        let(:text) do
          <<~JADE
            def pauls_birthday() -> { name : String, age : Int }
              paul_before_today = { name: "Paul", age: 55 }

              paul_before_today |> .age=(paul_before_today.age + 1)
            end
          JADE
        end

        it { is_expected.to be_a(AST::FunctionDeclaration) }

        it 'has a body with two expressions' do
          expect(subject.body.expressions).to have(2).items
          expect(subject.body.expressions.last).to be_a(AST::FunctionCall)
        end
      end
    end

    describe 'interop import' do
      include_context "single expression body"

      let(:text) do
        <<~JADE
          uses Jade::Date with today: Int
        JADE
      end

      it { is_expected.to be_a(AST::InteropImportDeclaration) }

      context 'with multiple imports' do
        let(:text) do
          <<~JADE
            uses Jade::Date with
              today: Int,
              today_plus_n_days: Int -> Int
          JADE
        end

        it { is_expected.to be_a(AST::InteropImportDeclaration) }
        its(:functions) { is_expected.to have(2).items }
      end
    end

    describe 'using an interop import' do
      subject { super().expressions.last }

      let(:text) do
        <<~JADE
          uses Jade::Date with today: Int

          def real_today() -> Int
            today()
          end
        JADE
      end

      it { is_expected.to be_a(AST::FunctionDeclaration) }
    end

    describe 'type args mismatch' do
      context 'extra args in a function' do
        let(:text) do
          <<~JADE
            def ten() -> Int(a)
              10
            end
          JADE
        end

        subject { frontend => Err(errors); errors }

        it { is_expected.to have(1).item }
        its([0]) { is_expected.to be_a(Frontend::SemanticAnalysis::Error::TypeArgsMismatch) }

        describe 'the error message' do
          subject { super()[0].message }

          it { is_expected.to eql '`Int` type needs 0 argument but got 1' }
        end
      end

      context 'extra args in a type declaration' do
        let(:text) do
          <<~JADE
            type Stuff(a, b) = Stuff(Maybe(a, b))
          JADE
        end

        subject { frontend => Err(errors); errors }

        it { is_expected.to have(1).item }
        its([0]) { is_expected.to be_a(Frontend::SemanticAnalysis::Error::TypeArgsMismatch) }

        describe 'the error message' do
          subject { super()[0].message }

          it { is_expected.to eql '`Maybe` type needs 1 argument but got 2' }
        end
      end

      context 'missing args in an interop import declaration' do
        let(:text) do
          <<~JADE
            uses Jade::Date with
              today: Maybe
          JADE
        end

        subject { frontend => Err(errors); errors }

        it { is_expected.to have(1).item }
        its([0]) { is_expected.to be_a(Frontend::SemanticAnalysis::Error::TypeArgsMismatch) }

        describe 'the error message' do
          subject { super()[0].message }

          it { is_expected.to eql '`Maybe` type needs 1 argument but got 0' }
        end
      end

      context 'missing args in a function' do
        let(:text) do
          <<~JADE
            def maybe_ten() -> Maybe
              Just(10)
            end
          JADE
        end

        subject { frontend => Err(errors); errors }

        it { is_expected.to have(1).item }
        its([0]) { is_expected.to be_a(Frontend::SemanticAnalysis::Error::TypeArgsMismatch) }

        describe 'the error message' do
          subject { super()[0].message }

          it { is_expected.to eql '`Maybe` type needs 1 argument but got 0' }
        end

        context 'missing args in record in a function' do
          let(:text) do
            <<~JADE
              def maybe_ten() -> { ten: Maybe }
                { ten: Just(10) }
              end
            JADE
          end

          subject { frontend => Err(errors); errors }

          it { is_expected.to have(1).item }
          its([0]) { is_expected.to be_a(Frontend::SemanticAnalysis::Error::TypeArgsMismatch) }

          describe 'the error message' do
            subject { super()[0].message }

            it { is_expected.to eql '`Maybe` type needs 1 argument but got 0' }
          end
        end
      end
    end

    context 'a struct declaration' do
      include_context "single expression body"

      let(:text) do
        <<~JADE
          struct Person = { name: String, age: Int }
        JADE
      end

      it { is_expected.to be_a(AST::StructDeclaration) }
    end

    context 'constructing a struct' do
      let(:text) do
        <<~JADE
          struct Person = { name: String, age: Int }
          Person("Guybrush", 28)
        JADE
      end

      subject { super().expressions.last }

      it { is_expected.to be_a(AST::FunctionCall) }
    end

    context 'pattern exhaustiveness' do
      let(:text) do
        <<~JADE
          case 1
          of 1 then True
          of 2 then True
          end
        JADE
      end

      subject { expect(frontend).to be_error; frontend => Err(errors); errors }

      it { is_expected.to have(1).item }
    end
  end
end
