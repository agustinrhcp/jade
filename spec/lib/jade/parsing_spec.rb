require 'spec_helper'

require 'jade/parsing'
require 'jade/lexer'
require 'jade/ast'

module Jade
  describe Parsing do
    let(:source) do
      Source.new(uri: 'test', text:)
    end

    let(:parse) { Lexer.tokenize(source).then { Parsing.parse(it) } }
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

        it { is_expected.to be_kind_of(Parsing::Error) }
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
        it { is_expected.to be_kind_of(Parsing::Error) }
      end

      context 'when it is incomplete with an incomplete string' do
        let(:text) do
          <<~JADE
            forty_two = "Hello
          JADE
        end

        subject { parse => Err(err); err }

        it { is_expected.to be_kind_of(Parsing::Error) }
        its(:message) { is_expected.to include("expected quote") }
      end
    end 

    context 'bind' do
      include_context "single expression body"

      let(:text) do
        <<~JADE
          result <- foo
        JADE
      end

      it { is_expected.to be_a(AST::Bind) }
      its(:name) { is_expected.to eql "result" }
      its(:expression) { is_expected.to be_a(AST::VariableReference) }
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
      its(:return_type) { is_expected.to be_a(AST::TypeApplication) }

      context 'without arguments' do
        let(:text) do
          <<~JADE
            def two() -> Int
              2
            end
          JADE
        end

        it { is_expected.to be_a(AST::FunctionDeclaration) }
      end
    end

    context 'a function declaration with qualified types' do
      include_context "single expression body"

      let(:text) do
        <<~JADE
          def add(a: Int, b: Int) -> Pepe.Lala
            a + b
          end
        JADE
      end

      it { is_expected.to be_a(AST::Node).and be_a(AST::FunctionDeclaration) }
      its(:name) { is_expected.to eql 'add' }
      its(:params) { is_expected.to have(2).items.and all(be_a(AST::FunctionDeclarationParam)) }
      its(:return_type) { is_expected.to be_a(AST::TypeApplication) }

      describe 'return type' do
        subject { super().return_type }

        its(:constructor) { is_expected.to be_a(AST::QualifiedTypeName) }
      end
    end

    context 'function declaration with type application' do
      include_context "single expression body"

      let(:text) do
        <<~JADE
          def map(result: Result(a, e), fn: a -> b) -> Result(b, e)
            case result
            of Ok(something) then Just(fn(somethig))
            of _ then result
            end
          end
        JADE
      end

      it { is_expected.to be_a(AST::FunctionDeclaration) }
    end

    context 'function declaration with lambda argument' do
      include_context "single expression body"

      let(:text) do
        <<~JADE
          def map(maybe: Maybe(a), fn: a -> b) -> Maybe(b)
            case maybe
            of Just(something) then fn(somethig)
            of Nothing then maybe
            end
          end
        JADE
      end

      it { is_expected.to be_a(AST::FunctionDeclaration) }

      describe 'its second param type' do
        subject { super().params.last => AST::FunctionDeclarationParam(type:); type }

        it { is_expected.to be_a(AST::TypeFunction) }

        describe 'the type function' do
          its(:params) { is_expected.to have(1).items.and all(be_a(AST::TypeVar)) }
          its(:return_type) { is_expected.to be_a(AST::TypeVar).and have_attributes(type: 'b') }
        end
      end

      context 'and type application' do
        let(:text) do
          <<~JADE
            def and_then(maybe: Maybe(a), fn: a -> Maybe(b)) -> Maybe(b)
              case maybe
              of Just(something) then fn(something)
              of Nothing then Nothing
              end
            end
          JADE
        end

        it { is_expected.to be_a(AST::FunctionDeclaration) }

        describe 'its second param type' do
          subject { super().params.last => AST::FunctionDeclarationParam(type:); type }

          it { is_expected.to be_a(AST::TypeFunction) }

          describe 'the type function' do
            its(:params) { is_expected.to have(1).items.and all(be_a(AST::TypeVar)) }
            its(:return_type) { is_expected.to be_a(AST::TypeApplication) }

            context 'the type application node' do
              subject { super().return_type }

              its(:args) { is_expected.to have(1).items }
            end
          end
        end
      end
    end

    context 'tuple type' do
      context 'as a parameter type' do
        include_context "single expression body"

        let(:text) do
          <<~JADE
            def something(tuple: (Int, String)) -> Int
              1
            end
          JADE
        end

        it { is_expected.to be_a(AST::FunctionDeclaration) }

        describe 'the param type' do
          subject { super().params.first => AST::FunctionDeclarationParam(type:); type }

          it { is_expected.to be_a(AST::TypeTuple) }
          its(:items) { is_expected.to have(2).items }
          its('items.first') { is_expected.to be_a(AST::TypeApplication) }
          its('items.last')  { is_expected.to be_a(AST::TypeApplication) }
        end
      end

      context 'as a return type' do
        include_context "single expression body"

        let(:text) do
          <<~JADE
            def something(a: Int) -> (String, Int)
              1
            end
          JADE
        end

        it { is_expected.to be_a(AST::FunctionDeclaration) }

        describe 'the return type' do
          subject { super().return_type }

          it { is_expected.to be_a(AST::TypeTuple) }
          its(:items) { is_expected.to have(2).items }
        end
      end

      context 'three elements' do
        include_context "single expression body"

        let(:text) do
          <<~JADE
            def something(a: Int) -> (String, Int, Bool)
              1
            end
          JADE
        end

        describe 'the return type' do
          subject { super().return_type }

          its(:items) { is_expected.to have(3).items }
        end
      end
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

      context 'pipe forward |>' do
        let(:text) do
          <<~JADE
            12 |> identity()
          JADE
        end

        it { is_expected.to be_a(AST::InfixApplication) }
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

      context 'with a record' do
        let(:text) do
          <<~JADE
            type Date = Date({ year: Int })
          JADE
        end

        it { is_expected.to be_a(AST::TypeDeclaration) }
        its(:name) { is_expected.to eql 'Date' }
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
      its(:exposing) { is_expected.to be_a AST::ExposeNone }

      context 'with exposing list' do
        let(:text) do
          <<~JADE
            import Maybe exposing (Maybe)
          JADE
        end

        it { is_expected.to be_a(AST::ImportDeclaration).and have_attributes(module_name: 'Maybe') }

        describe 'its exposing' do
          subject { super().exposing }

          it { is_expected.to be_a(AST::ExposeList)}
          its(:items) { is_expected.to have(1).item }

          it 'includes Maybe' do
            expect(subject.items.first).to be_a(AST::ExposeType).and have_attributes(name: 'Maybe')
          end
        end
      end

      context 'with exposing all' do
        let(:text) do
          <<~JADE
            import Maybe exposing (..)
          JADE
        end

        it { is_expected.to be_a(AST::ImportDeclaration).and have_attributes(module_name: 'Maybe') }
        its(:exposing) { is_expected.to be_a(AST::ExposeAll) }
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

      it { is_expected.to be_a(AST::Module) }
      its(:exposing) { is_expected.to be_a(AST::ExposeList) }

      describe 'its exposing' do
        subject { super().exposing }

        its(:items) { is_expected.to have(1).item }

        it 'includes hello' do
          expect(subject.items.first).to be_a(AST::ExposeValue)
          expect(subject.items.first.name).to eql 'hello'
        end
      end

      context 'exposing everything' do
        let(:text) do
          <<~JADE
            module Test exposing (..)

            def hello(str: String) -> Bool
              String.is_empty(str)
            end
          JADE
        end

        it { is_expected.to be_a(AST::Module) }
        its(:exposing) { is_expected.to be_a(AST::ExposeAll) }
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
      its(:condition) { is_expected.to be_a AST::FunctionCall }

      its(:if_branch) { is_expected.to be_a AST::Body }
      its(:else_branch) { is_expected.to be_a AST::Body }

      describe 'if branch' do
        subject { super().if_branch.expressions }

        it { is_expected.to have(1).item.and all(be_a(AST::Literal)) }
      end

      describe 'else branch' do
        subject { super().if_branch.expressions }

        it { is_expected.to have(1).item.and all(be_a(AST::Literal)) }
      end
    end

    context 'lambda' do
      include_context "single expression body"

      let(:text) do
        <<~JADE
          (one, two) -> { one + two }
        JADE
      end

      it { is_expected.to be_a(AST::Lambda) }
      its(:params) { is_expected.to have(2).items.and all(be_a(AST::LambdaParam)) }
      its(:body) { is_expected.to be_a(AST::Body) }
    end

    context 'grouping' do
      include_context "single expression body"

      let(:text) do
        <<~JADE
          (1 + 2)
        JADE
      end

      it { is_expected.to be_a(AST::Grouping) }

      context 'in the middle of an expression' do
        let(:text) do
          <<~JADE
            1 * (1 + 2) * 3
          JADE
        end

        it { is_expected.to be_a(AST::InfixApplication) }

        describe 'the expression' do
          it 'has a grouping' do
            expect(subject.left.right).to be_a(AST::Grouping)
          end
        end
      end
    end

    context 'tuple' do
      include_context "single expression body"

      context 'two elements' do
        let(:text) do
          <<~JADE
            (1, 2)
          JADE
        end

        it { is_expected.to be_a(AST::Tuple) }
        its(:items) { is_expected.to have(2).items }
        its('items.first') { is_expected.to be_a(AST::Literal) }
        its('items.last')  { is_expected.to be_a(AST::Literal) }
      end

      context 'three elements' do
        let(:text) do
          <<~JADE
            (1, 2, 3)
          JADE
        end

        it { is_expected.to be_a(AST::Tuple) }
        its(:items) { is_expected.to have(3).items }
      end

      context 'single element is still a grouping' do
        let(:text) do
          <<~JADE
            (1)
          JADE
        end

        it { is_expected.to be_a(AST::Grouping) }
      end

      context 'lambda with same syntax is not a tuple' do
        let(:text) do
          <<~JADE
            (a, b) -> { a }
          JADE
        end

        it { is_expected.to be_a(AST::Lambda) }
      end
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

      its(:expression) { is_expected.to be_a AST::Literal }
      its(:branches) { is_expected.to have(2).items.and all(be_a(AST::CaseOfBranch)) }

      describe 'the literal branch' do
        subject { super().branches.first }

        its(:pattern) { is_expected.to be_a(AST::Pattern::Literal) }
        its(:body) { is_expected.to be_a(AST::Body) }
      end

      describe 'the wildcard branch' do
        subject { super().branches[1] }

        its(:pattern) { is_expected.to be_a(AST::Pattern::Wildcard) }
        its(:body) { is_expected.to be_a(AST::Body) }
      end

      context 'with binding and constructor' do
        let(:text) do
          <<~JADE
            case Just(1)
            of Nothing then 0
            of Just(x) then x
            end
          JADE
        end

        describe 'the Nothing branch' do
          subject { super().branches.first }

          its(:pattern) { is_expected.to be_a(AST::Pattern::Constructor) }
        end

        describe 'the Just branch' do
          subject { super().branches[1] }

          its(:pattern) { is_expected.to be_a(AST::Pattern::Constructor) }

          context 'its patterns' do
            subject { super().pattern }

            its(:constructor) { is_expected.to be_a(AST::ConstructorReference).and have_attributes(name: 'Just') }
            its(:patterns) { is_expected.to have(1).item.and all(be_a(AST::Pattern::Binding)) }
          end
        end
      end

      context 'with record pattern' do
        let(:text) do
          <<~JADE
            case { name: "Pepe" }
            of { name: name } then name
            end
          JADE
        end

        describe 'the branch' do
          subject { super().branches.first }

          its(:pattern) { is_expected.to be_a(AST::Pattern::Record) }

          describe 'the record pattern' do
            subject { super().pattern }

            its(:fields) { is_expected.to have(1).items.and all(be_a(AST::Pattern::RecordField)) }

            describe 'the record pattern field' do
              subject { super().fields.first }

              its(:name) { is_expected.to eql "name" }
              its(:pattern) { is_expected.to be_a(AST::Pattern::Binding).and have_attributes(name: 'name') }
            end
          end
        end

        context 'with record pattern sugared' do
          let(:text) do
            <<~JADE
              case { name: "Pepe" }
              of { name: } then name
              end
            JADE
          end

          describe 'the branch' do
            subject { super().branches.first }

            its(:pattern) { is_expected.to be_a(AST::Pattern::Record) }

            describe 'the record pattern' do
              subject { super().pattern }

              its(:fields) { is_expected.to have(1).items.and all(be_a(AST::Pattern::RecordField)) }

              describe 'the record pattern field' do
                subject { super().fields.first }

                its(:name) { is_expected.to eql "name" }
                its(:pattern) { is_expected.to be_a(AST::Pattern::Binding).and have_attributes(name: 'name') }
              end
            end
          end
        end
      end
    end

    context 'list' do
      include_context "single expression body"

      let(:text) do
        <<~JADE
          [12, 42]
        JADE
      end

      it { is_expected.to be_a AST::List }
      its(:items) { is_expected.to all(be_a(AST::Literal)) }
    end

    context 'comment' do
      include_context "single expression body"

      let(:text) do
        <<~JADE
          # This is a comment
          type Pepe = Lala
        JADE
      end

      it { is_expected.to be_a AST::TypeDeclaration }
    end

    describe 'record literal' do
      include_context "single expression body"

      let(:text) do
        <<~JADE
          { a: "Hello", b: 2 }
        JADE
      end

      it { is_expected.to be_a AST::RecordLiteral }
      its(:fields) { is_expected.to have(2).items.and all(be_a(AST::RecordField)) }
    end

    describe 'record update' do
      include_context "single expression body"

      let(:text) do
        <<~JADE
          { a | b: 2 }
        JADE
      end

      it { is_expected.to be_a AST::RecordUpdate }
      its(:base) { is_expected.to be_a(AST::VariableReference).and have_attributes(name: 'a') }
      its(:fields) { is_expected.to have(1).items.and all(be_a(AST::RecordField)) }

      context 'with operation' do
        let(:text) do
          <<~JADE
            def pauls_birthday() -> Person
              paul_before_today = paul()
              { paul_before_today | age: paul_before_today.age + 1 }
            end
          JADE
        end

        it { is_expected.to be_a AST::FunctionDeclaration }

        describe 'the record update' do
          subject { super().body.expressions.last }

          it { is_expected.to be_a AST::RecordUpdate }
          its(:base) { is_expected.to be_a(AST::VariableReference).and have_attributes(name: 'paul_before_today') }
        end
      end
    end

    describe 'record update sugar' do
      include_context "single expression body"

      let(:text) do
        <<~JADE
          .b=
        JADE
      end

      it { is_expected.to be_a AST::RecordUpdateSugar }
      its(:field_key) { is_expected.to eql 'b' }
    end

    describe 'record access sugar' do
      include_context "single expression body"

      let(:text) do
        <<~JADE
          .b
        JADE
      end

      it { is_expected.to be_a AST::RecordAccessSugar }
      its(:field_key) { is_expected.to eql 'b' }
    end

    context 'a record type expression' do
      include_context "single expression body"

      let(:text) do
        <<~JADE
          def add() -> { name : String, age : Int }
            { name: "Paul", age: 55 }
          end
        JADE
      end

      it { is_expected.to be_a AST::FunctionDeclaration }
      its(:return_type) { is_expected.to be_a(AST::TypeRecord) }

      describe 'the type record' do
        subject { super().return_type }

        its(:fields) do
          is_expected.to have(2).items
          is_expected.to have_key('name')
          is_expected.to have_key('age')
        end

        describe "name field" do
          subject { super().fields['name'] }

          it { is_expected.to be_a(AST::TypeApplication) }
          its(:constructor) { is_expected.to be_a(AST::TypeName).and have_attributes(type: 'String') }
        end

        describe "age field" do
          subject { super().fields['age'] }

          it { is_expected.to be_a(AST::TypeApplication) }
          its(:constructor) { is_expected.to be_a(AST::TypeName).and have_attributes(type: 'Int') }
        end
      end

      context 'an open record type' do
        let(:text) do
          <<~JADE
            def name(thing: { a | name : String }) -> String
              thing.name
            end
          JADE
        end

        it { is_expected.to be_a AST::FunctionDeclaration }
        its(:params) { is_expected.to have(1).item }

        describe 'the first param' do
          subject { super().params.first }

          its(:name) { is_expected.to eql 'thing' }
          its(:type) { is_expected.to be_a(AST::TypeRecord) }

          describe 'the record type' do
            subject { super().type }

            its(:fields) { is_expected.to have(1).item }
            its(:row_var) { is_expected.to be_a(AST::TypeParam).and have_attributes(name: 'a') }
          end
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
      its(:module) { is_expected.to be_a(AST::InteropModule).and have_attributes(name: 'Jade::Date') }
      its(:functions) { is_expected.to have(1).item.and all(be_a(AST::InteropFunction)) }

      describe 'the function' do
        subject { super().functions.first }
        its(:name) { is_expected.to eql 'today' }
        its(:type) { is_expected.to be_a(AST::TypeApplication) }
        it { expect(subject.type.constructor.type).to eql 'Int' }
      end

      context 'with multiple functions' do
        let(:text) do
          <<~JADE
            uses Jade::Date with
              today: Int,
              today_plus_days: Int -> Int
          JADE
        end

        it { is_expected.to be_a(AST::InteropImportDeclaration) }
        its(:functions) { is_expected.to have(2).items }
      end
    end

    describe 'interop import' do
      include_context "single expression body"

      let(:text) do
        <<~JADE
          struct Person = { name: String }
        JADE
      end

      it { is_expected.to be_a(AST::StructDeclaration) }
    end

    describe 'not_eq' do
      include_context "single expression body"

      let(:text) do
        <<~JADE
          1 != 2
        JADE
      end

      it { is_expected.to be_a(AST::InfixApplication) }
    end

    xdescribe 'interface' do
    end

    describe 'implements' do
      include_context "single expression body"

      let(:text) do
        <<~JADE
          implements Eq(Pepe) with
            (==) : eq_pepe
          end
        JADE
      end

      it { is_expected.to be_a(AST::Implementation) }
    end
  end
end
