require 'spec_helper'

require 'jade/symbol'
require 'jade/type'
require 'jade/frontend'
require 'jade/parsing'
require 'jade/lexer'
require 'jade/ast'

using Jade::TypeFactory

module Jade
  module Frontend
    describe TypeChecking do
      let(:source) do
        Source.new(uri: 'test', text:)
      end

      let(:type_check) do
        Lexer
          .tokenize(source)
          .then { Parsing.parse(it, entry: source.uri) }
          .and_then { |(ast, _)| Frontend.run_up_to_semantic_analysis(ast) }
          # TODO: Make this prettier
          .and_then do |entry, registry|
            env = TypeChecking::Loader.load(entry, registry)
            state = TypeChecking::State.init(env)
            check_state, result = TypeChecking.check_node(
              entry.ast,
              registry,
              state,
              TypeChecking::Expected.infer(state.fresh),
            )
            Data.define(:type, :errors, :env).new(
              type: result.type,
              errors: check_state.errors,
              env: check_state.env,
            )
          end
      end

      subject { type_check }

      context 'literals' do
        let(:text) do
          <<~JADE
            42
          JADE
        end

        its(:type) { is_expected.to eql Type.int }
      end

      context 'a function declaration' do
        let(:text) do
          <<~JADE
            def add(a: Int, b: Int) -> Int
              a
            end
          JADE
        end

        its(:type) { is_expected.to eql Type.unit }
        its(:errors) { is_expected.to be_empty }

        context 'it binds the function to the env' do
          subject { super().env }

          its(:bindings) do
            is_expected.to have_key('__Test__.add')
            is_expected.to include(
              '__Test__.add' => TypeChecking::Placeholder[
                Type.function([Type.int, Type.int], Type.int),
                [],
              ]
            )
          end
        end

        context 'with a longer body' do
          let(:text) do
            <<~JADE
              def add(a: Int, b: Int) -> Int
                c = 10

                c
              end
            JADE
          end

          its(:type) { is_expected.to eql Type.unit }
          its(:errors) { is_expected.to be_empty }
        end

        context 'when type return type and the body types mismatch' do
          let(:text) do
            <<~JADE
              def add(a: Int, b: Int) -> Int
                "Hello"
              end
            JADE
          end

          its(:type) { is_expected.to eql Type.unit }
          its(:errors) { is_expected.to have(1).item }

          describe 'the error' do
            subject { super().errors.first }
            it { is_expected.to be_a(TypeChecking::Error::FunctionBodyTypeMismatch) }
            its(:message) { is_expected.to include('it returns String but its signature says it should be Int') }
            its(:entry) { is_expected.to eql '__Test__' }
          end
        end

        context 'with rigid type param' do
          let(:text) do
            <<~JADE
              def nope(result: a) -> Result(a, String)
                Ok(result)
              end
            JADE
          end

          its(:type) { is_expected.to eql Type.unit }
          its(:errors) { is_expected.to be_empty }
        end

        context 'with rigid type param  that matches' do
          let(:text) do
            <<~JADE
              def nope(result: a) -> Result(a, error)
                Ok(result)
              end
            JADE
          end

          its(:type) { is_expected.to eql Type.unit }
          its(:errors) { is_expected.to be_empty }
        end

        context 'with Ok([]) and Result(List(Int), String) return type' do
          let(:text) do
            <<~JADE
              def example() -> Result(List(Int), String)
                Ok([])
              end
            JADE
          end

          its(:type) { is_expected.to eql Type.unit }
          its(:errors) { is_expected.to be_empty }
        end
      end

      context 'a variable binding' do
        let(:text) do
          <<~JADE
            hello = "Hola"
          JADE
        end

        its(:type) { is_expected.to eql Type.string }
        its(:errors) { is_expected.to be_empty }

        context 'it binds the variable to the env' do
          subject { super().env }

          its(:bindings) do
            is_expected.to have_key('hello')
            is_expected.to include('hello' => TypeChecking::Scheme.mono(Type.string))
          end
        end
      end

      context 'infix application' do
        let(:text) do
          <<~JADE
            2 * 2 + 3 * 3
          JADE
        end

        its(:type) { is_expected.to eql Type.int }
        its(:errors) { is_expected.to be_empty }

        context 'when calling with the wrong params' do
          let(:text) do
            <<~JADE
              2 * "Hello"
            JADE
          end

          its(:type) { is_expected.to eql Type.int }
          its(:errors) { is_expected.to have(1).item }

          describe 'the error' do
            subject { super().errors.first }

            it { is_expected.to be_a(TypeChecking::Error::FunctionCallTypeMismatch) }
            its(:message) { is_expected.to include('Right side of (*) expects Int but found String') }
          end
        end
      end

      context 'a function declaration' do
        let(:text) do
          <<~JADE
            def add(a: Int, b: Int) -> Int
              a + b
            end
            add(1, 2)
          JADE
        end

        its(:type) { is_expected.to eql Type.int }
        its(:errors) { is_expected.to be_empty }

        context 'when calling with the wrong params' do
          let(:text) do
            <<~JADE
              def add(a: Int, b: Int) -> Int
                a + b
              end
              add(1, "Hello")
            JADE
          end

          its(:type) { is_expected.to eql Type.int }
          its(:errors) { is_expected.to have(1).item }

          describe 'the error' do
            subject { super().errors.first }
            it { is_expected.to be_a(TypeChecking::Error::FunctionCallTypeMismatch) }
            its(:message) { is_expected.to include('Function call mismatch, expected (Int, Int) -> Int but found (Int, String) -> Int') }
          end
        end
      end

      context 'a function call' do
        let(:text) do
          <<~JADE
            def add(a: Int, b: Int) -> Int
              a + b
            end
            add(1, "Hello")
          JADE
        end
      end

      context 'type def and reference' do
        let(:text) do
          <<~JADE
            type Maybe(a)
              = Just(a)
              | Nothing
            Just
          JADE
        end

        its(:type) { is_expected.to be_a(Type::Function) }
        its(:errors) { is_expected.to be_empty }

        describe 'the type' do
          subject { super().type }
          its(:args) { is_expected.to have(1).items }
          its(:return_type) { is_expected.to be_a(Type::Application).and have_attributes(constructor: Type.constructor('__Test__.Maybe')) }
        end

        describe 'and call' do
          let(:text) do
            <<~JADE
              type Maybe(a)
                = Just(a)
                | Nothing
              Just(12)
            JADE
          end

          its(:type) { is_expected.to eql Type.constructor('__Test__.Maybe').apply([Type.int]) }
          its(:errors) { is_expected.to be_empty }
        end

        describe 'and call with different type application' do
          let(:text) do
            <<~JADE
              type Maybe(a)
                = Just(a)
                | Nothing
              Just(12)
              Just("Hello")
            JADE
          end

          its(:type) { is_expected.to eql Type.constructor('__Test__.Maybe').apply([Type.string]) }
          its(:errors) { is_expected.to be_empty }
        end

        describe 'and call with wrong params' do
          let(:text) do
            <<~JADE
              type Maybe(a)
                = Just(a, a)
                | Nothing
              Just(12, "Hello")
            JADE
          end

          its(:errors) { is_expected.to have(1).item }

          describe 'the error' do
            subject { super().errors.first }

            its(:message) { is_expected.to eql "Function call mismatch, expected (Int, Int) -> Maybe(Int) but found (Int, String) -> Maybe(Int)" }
          end
        end
      end

      context 'if then else' do
        let(:text) do
          <<~JADE
            if String.is_empty("") then
              1
            else
              2
            end
          JADE
        end

        its(:type) { is_expected.to eql Type.int }
        its(:errors) { is_expected.to be_empty }

        context 'when the condition is not a boolean' do
          let(:text) do
            <<~JADE
              if "" then
                1
              else
                2
              end
            JADE
          end

          its(:type) { is_expected.to eql Type.int }
          its(:errors) { is_expected.to_not be_empty }

          describe 'the error' do
            subject { super().errors.first }

            it { is_expected.to be_a(TypeChecking::Error::IfConditionTypeMismatch) }
            its(:message) { is_expected.to include('If condition expects Bool but found String') }
          end
        end

        context 'when the branches have different types' do
          let(:text) do
            <<~JADE
              if String.is_empty("") then
                1
              else
                "two"
              end
            JADE
          end

          its(:type) { is_expected.to eql Type.string }
          its(:errors) { is_expected.to_not be_empty }

          describe 'the error' do
            subject { super().errors.first }

            it { is_expected.to be_a(TypeChecking::Error::IfBranchesTypeMismatch) }
            its(:message) { is_expected.to include('If branches must return the same type. The then branch produces Int but the else branch produces String') }
          end
        end
      end

      context 'case of' do
        let(:text) do
          <<~JADE
            case 1
            of 1 then 1
            of _ then 2
            end
          JADE
        end

        its(:type) { is_expected.to eql Type.int }
        its(:errors) { is_expected.to be_empty }

        context 'when pattern type is invalid' do
          let(:text) do
            <<~JADE
              case 1
              of "" then 1
              of _ then 2
              end
            JADE
          end

          its(:type) { is_expected.to eql Type.int }
          its(:errors) { is_expected.to_not be_empty }

          describe 'the error' do
            subject { super().errors.first }
            it { is_expected.to be_a TypeChecking::Error::PatternTypeMismatch }

            its(:message) { is_expected.to include 'Pattern is trying to match Int with String' }
          end
        end

        context 'when branches are of different type' do
          let(:text) do
            <<~JADE
              case 1
              of 1 then 1
              of _ then "two"
              end
            JADE
          end

          its(:type) { is_expected.to eql Type.int }
          its(:errors) { is_expected.to_not be_empty }

          describe 'the error' do
            subject { super().errors.first }
            it { is_expected.to be_a TypeChecking::Error::CaseOfBranchesTypeMismatch }

            its(:message) { is_expected.to include 'First branch of this case statement is Int but 2nd branch is String' }
          end
        end

        context 'with variable binding branches' do
          let(:text) do
            <<~JADE
              case 1
              of 1 then 1
              of x then x
              end
            JADE
          end

          its(:type) { is_expected.to eql Type.int }
          its(:errors) { is_expected.to be_empty }
        end

        context 'with constructor pattern' do
          let(:text) do
            <<~JADE
              type Maybe(a)
                = Just(a)
                | Nothing
              case Just(1)
              of Nothing then 0
              of Just(x) then x
              end
            JADE
          end

          its(:type) { is_expected.to eql Type.int }
          its(:errors) { is_expected.to be_empty }
        end
      end

      describe 'record literal' do
        let(:text) do
          <<~JADE
            {
              a: "hello",
              b: 42,
            }
          JADE
        end

        its(:type) { is_expected.to eql Type.anonymous_record({ 'a' => Type.string, 'b' => Type.int }, nil) }
      end

      describe 'unification edge cases' do
        describe 'anotation rigidity' do
          let(:text) do
            <<~JADE
              def f() -> a
                1
              end
            JADE
          end

          its(:errors) { is_expected.to have(1).item }

          describe 'the error' do
            subject { super().errors.first }

            its(:message) { is_expected.to include 'it returns Int but its signature says it should be a' }
          end

          context 'with an if' do
            let(:text) do
              <<~JADE
                def f(x: a) -> a
                  if True then
                    x
                  else
                    1
                  end
                end
              JADE
            end

            its(:errors) { is_expected.to have(2).item }

            describe 'the error' do
              subject { super().errors.map(&:message).join(' ') }

              it { is_expected.to include 'it returns Int but its signature says it should be a' }
              it { is_expected.to include "If branches must return the same type" }
            end
          end

          context 'open record' do
            let(:text) do
              <<~JADE
                def f(x: a) -> { id: a }
                  { id: 1 }
                end
              JADE
            end

            its(:errors) { is_expected.to have(1).item }

            describe 'the error' do
              subject { super().errors.map(&:message).join(' ') }

              it { is_expected.to eql "There's a problem with the body of `f` definition: it returns { id : Int } but its signature says it should be { id : a }" }
            end
          end
        end

        describe 'identity function' do
          let(:text) do
            <<~JADE
              def f(x: a) -> a
                x
              end
            JADE
          end

          its(:errors) { is_expected.to be_empty  }
        end

        describe 'calling identity function' do
          let(:text) do
            <<~JADE
              def f(x: a) -> a
                x
              end

              f(1)
              f("one")
            JADE
          end

          its(:errors) { is_expected.to be_empty  }
        end

        describe 'loop function' do
          let(:text) do
            <<~JADE
              def f(x: a) -> b
                f(x)
              end
            JADE
          end

          its(:errors, 'this function never returns so typechecks with bananas') { is_expected.to be_empty  }
        end
      end

      describe 'lambdas' do
        let(:text) do
          <<~JADE
            (a, b) -> { a + b }
          JADE
        end

        its(:type) { is_expected.to be_a(Type::Function) }
        its(:type) { is_expected.to satisfy { |t| t.args.first == t.return_type } }

        context 'with constructor pattern param (single constructor)' do
          let(:text) do
            <<~JADE
              type Box(a) = Box(a)

              fn = (Box(x)) -> { x }
            JADE
          end

          its(:type) { is_expected.to be_a(Type::Function) }
          its(:errors) { is_expected.to be_empty }
        end

        context 'with wildcard param' do
          let(:text) do
            <<~JADE
              (_) -> { 42 }
            JADE
          end

          its(:type) { is_expected.to be_a(Type::Function) }
          its(:errors) { is_expected.to be_empty }
        end

        context 'with non-exhaustive constructor pattern param' do
          let(:text) do
            <<~JADE
              type Maybe(a)
                = Just(a)
                | Nothing

              fn = (Just(x)) -> { x }
            JADE
          end

          its(:errors) { is_expected.to include(be_a(TypeChecking::Error::MissingPatterns)) }
        end
      end

      describe'struct def and reference' do
        let(:text) do
          <<~JADE
            struct Person = {
              name: String,
              age: Int
            }
            Person
          JADE
        end

        its(:type) { is_expected.to be_a(Type::Function) }
        its(:errors) { is_expected.to be_empty }

        context 'instantiation' do
          let(:text) do
            <<~JADE
              struct Person = {
                name: String,
                age: Int
              }
              Person("Paul", 55)
            JADE
          end

          its(:type) { is_expected.to be_a(Type::Application).and have_attributes(constructor: Type.constructor('__Test__.Person')) }
          its(:errors) { is_expected.to be_empty }
        end

        context 'in function declaration' do
          let(:text) do
            <<~JADE
              struct Person = {
                name: String,
                age: Int
              }
              def person(name: String, age: Int) -> Person
                Person(name, age)
              end
            JADE
          end

          its(:type) { is_expected.to eql Type.unit }
          its(:errors) { is_expected.to be_empty }
        end

        context 'unifying against a record' do
          let(:text) do
            <<~JADE
              struct Person = {
                name: String,
                age: Int
              }
              def person(name: String, age: Int) -> { name: String, age: String }
                Person(name, age)
              end
            JADE
          end

          its(:errors) { is_expected.to have(1).item  }
          context 'the message' do
            subject { super().errors.map(&:message).join(', ') }

            it { is_expected.to include "expected { name : String, age : String } but found Person" }
          end
        end

        context 'unifying against an open record' do
          let(:text) do
            <<~JADE
              struct Person = {
                name: String,
                age: Int
              }
              def name(named: { a | name: String }) -> String
                named.name
              end
              name(Person("Paul", 55))
            JADE
          end

          its(:type) { is_expected.to eql Type.string }
          its(:errors) { is_expected.to be_empty }
        end

        context 'with type params' do
          let(:text) do
            <<~JADE
              struct Person(id) = {
                name: String,
                id: id
              }
              def identified(name: String, id: a) -> Person(a)
                Person(name, id)
              end
              Person("Paul", 1)
              Person("Frank", "asdf-1234")
            JADE
          end

          its(:type) { is_expected.to be_a(Type::Application) }
          its(:errors) { is_expected.to be_empty }
        end

        context 'with type params' do
          let(:text) do
            <<~JADE
              def id(rec: { a | id: id }) -> id
                rec.id
              end
            JADE
          end

          its(:type) { is_expected.to eql Type.unit }
          its(:errors) { is_expected.to be_empty }
        end
      end

      describe 'constraint propagation from !=' do
        let(:text) do
          <<~JADE
            def neq(a: a, b: a) -> Bool
              a != b
            end
          JADE
        end

        its(:errors) { is_expected.to be_empty }

        context 'the function binding' do
          subject { super().env.bindings['__Test__.neq'] }

          it 'has an Eq constraint' do
            is_expected.to have_attributes(
              constraints: include(having_attributes(interface: 'Basics.Eq', type: be_a(Type::Var)))
            )
          end
        end
      end
    end
  end
end
