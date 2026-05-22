require 'spec_helper'

require 'jade'
require 'jade/module_loader'

module Jade
  describe 'Recordss' do
    include_context 'with test compiler'

    describe 'record literal' do
      let(:pepe_source) do
        <<~JADE
          module Pepe exposing (person)

          def person -> { name: String, age: Int }
            {
              name: "Paul",
              age: 55,
            }
        JADE
      end

      it 'generates a person with the right attributes' do
        expect { test_compiler.require('pepe', pepe_source) }.to_not raise_error

        expect(Pepe::Internal.person.call()).to have_attributes(name: 'Paul', age: 55)
      end

      context 'when signature does not match' do
        let(:pepe_source) do
          <<~JADE
            module Pepe exposing (person)

            def person -> { name: String, age: Float }
              {
                name: "Paul",
                age: 55,
              }
          JADE
        end

        it 'fails with type mismatch' do
          expect { test_compiler.require('pepe', pepe_source) }
            .to raise_error(CompilationError, /it returns { name : String, age : Int } but its signature says it should be { name : String, age : Float }/)
        end
      end

      context 'accessing a field' do
        let(:pepe_source) do
          <<~JADE
            module Pepe exposing (paul, pauls_age)

            def paul -> { name: String, age: Int }
              {
                name: "Paul",
                age: 55,
              }


            def pauls_age -> Int
              paul.age
          JADE
        end

        it 'returns the age' do
          expect { test_compiler.require('pepe', pepe_source) }.to_not raise_error

          expect(Pepe.pauls_age()).to eql 55
        end

        context 'sugar acces to a' do
          let(:pepe_source) do
            <<~JADE
              module Pepe exposing (paul, pauls_age)

              def paul -> { name: String, age: Int }
                {
                  name: "Paul",
                  age: 55,
                }


              def pauls_age -> Int
                paul |> .age
            JADE
          end

          it 'returns the age' do
            expect { test_compiler.require('pepe', pepe_source) }.to_not raise_error

            expect(Pepe.pauls_age()).to eql 55
          end
        end

        context 'accessing a field that does not exist' do
          let(:pepe_source) do
            <<~JADE
              module Pepe exposing (paul, pauls_age)

              def paul -> { name: String, age: Int }
                {
                  name: "Paul",
                  age: 55,
                }


              def pauls_age -> Int
                paul.ate
            JADE
          end

          it 'fails with type mismatch' do
            expect { test_compiler.require('pepe', pepe_source) }
              .to raise_error(CompilationError, /it expects { a | ate : Int } but found { name : String, age : Int }>/)
          end
        end
      end

      describe 'updating a field' do
        let(:pepe_source) do
          <<~JADE
            module Pepe exposing (paul, pauls_birthday)

            def paul -> { name: String, age: Int }
              {
                name: "Paul",
                age: 55,
              }


            def pauls_birthday -> { name: String, age: Int }
              paul_before_today = paul

              { paul_before_today | age: paul_before_today.age + 1 }
          JADE
        end

        it 'updates the record' do
          expect { test_compiler.require('pepe', pepe_source) }.to_not raise_error

          expect(Pepe::Internal.pauls_birthday.call()).to have_attributes(name: 'Paul', age: 56)
        end
      end

      describe 'updating a field with sugar on top' do
        let(:pepe_source) do
          <<~JADE
            module Pepe exposing (paul, pauls_birthday)

            def paul -> { name: String, age: Int }
              {
                name: "Paul",
                age: 55,
              }


            def pauls_birthday -> { name: String, age: Int }
              paul_before_today = paul

              paul_before_today |> .age=(paul_before_today.age + 1)
          JADE
        end

        it 'updates the record' do
          expect { test_compiler.require('pepe', pepe_source) }.to_not raise_error

          expect(Pepe::Internal.pauls_birthday.call()).to have_attributes(name: 'Paul', age: 56)
        end
      end

      describe 'with type params' do
        let(:pepe_source) do
          <<~JADE
            module Pepe exposing (franks_id, pauls_id)

            def id(rec: { a | id: id }) -> id
              rec.id


            def pauls_id -> Int
              {
                name: "Paul",
                id: 10,
              } |> id


            def franks_id -> String
              {
                name: "Paul",
                id: "f10",
              } |> id
          JADE
        end

        it 'updates the record' do
          expect { test_compiler.require('pepe', pepe_source) }.to_not raise_error

          expect(Pepe.pauls_id()).to eql(10)
          expect(Pepe.franks_id()).to eql("f10")
        end
      end

      describe 'pattern matching' do
        let(:pepe_source) do
          <<~JADE
            module Pepe exposing (frank_is_paul, paul_is_paul)

            def is_paul(person: { name: String, id: Int }) -> Bool
              case person
              of { name: "Paul" } -> True
              of _ -> False


            def paul_is_paul -> Bool
              {
                name: "Paul",
                id: 10,
              } |> is_paul


            def frank_is_paul -> Bool
              {
                name: "Frank",
                id: 20,
              } |> is_paul
          JADE
        end

        it 'updates the record' do
          expect { test_compiler.require('pepe', pepe_source) }.to_not raise_error

          expect(Pepe.paul_is_paul()).to be true
          expect(Pepe.frank_is_paul()).to be false
        end

        context "with wrong field type" do
          let(:pepe_source) do
            <<~JADE
              module Pepe exposing (is_paul)

              def is_paul(person: { name: String, id: Int }) -> Bool
                case person
                of { name: 1 } -> True
                of _ -> False
            JADE
          end

          it 'fails with type mismatch' do
            expect { test_compiler.require('pepe', pepe_source) }
              .to raise_error(CompilationError, /Pattern is trying to match { name : String, id : Int } with { t11 | name : Int }/)
          end
        end

        context "with wrong constructor type" do
          let(:pepe_source) do
            <<~JADE
              module Pepe exposing (is_paul)

              def is_paul(person: { name: String, id: Int }) -> Bool
                case person
                of { name: Just("Pepe") } -> True
                of _ -> False
            JADE
          end

          it 'fails with type mismatch' do
            expect { test_compiler.require('pepe', pepe_source) }
              .to raise_error(CompilationError, /Pattern is trying to match { name : String, id : Int } with { t\d+ | name : Maybe(String) }/)
          end
        end
      end
    end

    describe 'struct' do
      let(:pepe_source) do
        <<~JADE
          module Pepe exposing (person)

          struct Person = {
            name: String,
            age: Int
          }


          def person -> Person
            Person("Paul", 55)
        JADE
      end

      it 'generates a person with the right attributes' do
        expect { test_compiler.require('pepe', pepe_source) }.to_not raise_error

        expect(Pepe::Internal.person.call()).to have_attributes(name: 'Paul', age: 55)
      end

      context 'accessor' do
        let(:pepe_source) do
          <<~JADE
            module Pepe exposing (pauls_name)

            struct Person = {
              name: String,
              age: Int
            }


            def named(thing: { a | name: String }) -> String
              thing.name


            def pauls_name -> String
              Person("Paul", 55) |> named()
          JADE
        end

        it 'generates a person with the right attributes' do
          expect { test_compiler.require('pepe', pepe_source) }.to_not raise_error

          expect(Pepe.pauls_name()).to eql('Paul')
        end
      end

      context 'with type params' do
        let(:pepe_source) do
          <<~JADE
            module Pepe exposing (frank, identified, paul)

            struct Person(a) = {
              name: String,
              id: a
            }


            def paul -> Person(Int)
              Person("Paul", 1)


            def frank -> Person(String)
              Person("Frank", "f10")


            def identified(ided: { a | id: id }) -> id
              ided.id
          JADE
        end

        it 'generates a person with the right attributes' do
          expect { test_compiler.require('pepe', pepe_source) }.to_not raise_error

          expect(Pepe::Internal.paul.call().id).to eql(1)
          expect(Pepe::Internal.frank.call().id).to eql('f10')
        end
      end

      describe 'pattern matching' do
        let(:pepe_source) do
          <<~JADE
            module Pepe exposing (frank_is_paul, paul_is_paul)

            struct Person = {
              name: String,
              id: Int
            }


            def is_paul(person: Person) -> Bool
              case person
              of { name: "Paul" } -> True
              of _ -> False


            def paul_is_paul -> Bool
              Person("Paul", 10) |> is_paul


            def frank_is_paul -> Bool
              Person("Frank", 20) |> is_paul
          JADE
        end

        it 'updates the record' do
          expect { test_compiler.require('pepe', pepe_source) }.to_not raise_error

          expect(Pepe.paul_is_paul()).to be true
          expect(Pepe.frank_is_paul()).to be false
        end
      end

      describe 'pipe-sugar update on a struct returns the struct' do
        let(:pepe_source) do
          <<~JADE
            module Pepe exposing (birthday)

            struct Person = {
              name: String,
              age: Int
            }


            def birthday(p: Person) -> Person
              p |> .age=(p.age + 1)
          JADE
        end

        it 'preserves the nominal struct type through the pipe' do
          expect { test_compiler.require('pepe', pepe_source) }.not_to raise_error

          paul = Pepe::Person['Paul', 55]
          expect(Pepe::Internal.birthday.call(paul)).to eql Pepe::Person['Paul', 56]
        end
      end

      describe 'referencing a nullary function from another function' do
        let(:pepe_source) do
          <<~JADE
            module Pepe exposing (name_of_paul)

            struct Person = {
              name: String,
              age: Int
            }


            def paul -> Person
              Person("Paul", 55)


            def name_of_paul -> String
              paul.name
          JADE
        end

        it 'reads `paul` as a value (bare reference)' do
          expect { test_compiler.require('pepe', pepe_source) }.not_to raise_error
          expect(Pepe.name_of_paul()).to eql 'Paul'
        end
      end

      describe 'passing the result of a nullary call to a polymorphic function' do
        let(:pepe_source) do
          <<~JADE
            module Pepe exposing (query)

            struct Table(c) = { val: c }


            def get_val(t: Table(c)) -> c
              t.val


            def persons -> Table(Int)
              Table(42)


            def query -> Int
              get_val(persons)
          JADE
        end

        it 'instantiates the type parameter from the call result' do
          expect { test_compiler.require('pepe', pepe_source) }.not_to raise_error
          expect(Pepe.query()).to eql 42
        end
      end

      describe 'wrapping a record literal in a struct constructor is rejected' do
        let(:pepe_source) do
          <<~JADE
            module Pepe exposing (paul)

            struct Person = {
              name: String,
              age: Int
            }


            def paul -> Person
              Person({
                name: "Paul",
                age: 55,
              })
          JADE
        end

        it 'fails to compile' do
          expect { test_compiler.require('pepe', pepe_source) }
            .to raise_error(CompilationError, /Function call mismatch/)
        end
      end

      describe 'wrapping a record update in a struct constructor is rejected' do
        let(:pepe_source) do
          <<~JADE
            module Pepe exposing (older_paul)

            struct Person = {
              name: String,
              age: Int
            }


            def paul -> Person
              Person("Paul", 55)


            def older_paul -> Person
              Person({ paul | age: 56 })
          JADE
        end

        it 'fails to compile' do
          expect { test_compiler.require('pepe', pepe_source) }
            .to raise_error(CompilationError, /Function call mismatch/)
        end
      end

      describe 'parameterized struct with a record-typed param accepts anon record' do
        let(:pepe_source) do
          <<~JADE
            module Pepe exposing (wrap)

            struct Wrapper(a) = { wrapped: a }


            def wrap -> Wrapper({ val: Int })
              Wrapper({ val: 42 })
          JADE
        end

        it 'positional construction with the record as the type-param value' do
          expect { test_compiler.require('pepe', pepe_source) }.not_to raise_error
          expect(Pepe::Internal.wrap.call().wrapped.val).to eql(42)
        end
      end

      describe 'construction forms (catalogue)' do
        let(:working_source) do
          <<~JADE
            module Forms exposing (kwargs, nested, positional, update)

            struct Address = {
              street: String,
              city: String
            }


            struct Wrapper = { addr: Address }


            struct Person = {
              name: String,
              age: Int
            }


            def positional -> Person
              Person("Paul", 55)


            def kwargs -> Person
              Person(name: "Paul", age: 55)


            def update -> Person
              base = Person("Paul", 55)

              { base | age: 56 }


            def nested -> Wrapper
              Wrapper(Address("Main", "Paris"))
          JADE
        end

        it 'positional, kwargs, update, and nested all work' do
          test_compiler.require('forms', working_source)

          expected_person = Forms::Person['Paul', 55]
          expect(Forms::Internal.positional.call).to eql expected_person
          expect(Forms::Internal.kwargs.call).to     eql expected_person

          expect(Forms::Internal.update.call).to eql Forms::Person['Paul', 56]
          expect(Forms::Internal.nested.call).to eql Forms::Wrapper[Forms::Address['Main', 'Paris']]
        end

        it 'anonymous record cannot stand in for a nominal struct' do
          source = <<~JADE
            module Forms exposing (bad)

            struct Address = {
              street: String,
              city: String
            }


            struct Wrapper = { addr: Address }


            def bad -> Wrapper
              Wrapper({
                street: "Main",
                city: "Paris",
              })
          JADE

          expect { test_compiler.require('forms_bad', source) }
            .to raise_error(CompilationError, /Address/)
        end
      end

      describe 'kwargs validation' do
        def compile(body)
          source = <<~JADE
            module M exposing (f)

            struct Person = {
              name: String,
              age: Int
            }


            def f -> Person
              #{body}
          JADE

          test_compiler.require('m', source)
        end

        it 'rejects unknown fields with a pointed error' do
          expect { compile('Person(name: "Paul", age: 55, nickname: "Pablo")') }
            .to raise_error(CompilationError, /`Person` has no field `nickname` \(has: `name`, `age`\)/)
        end

        it 'rejects missing fields' do
          expect { compile('Person(name: "Paul")') }
            .to raise_error(CompilationError, /`Person` is missing field `age:`/)
        end

        it 'rejects duplicate fields' do
          expect { compile('Person(name: "Paul", name: "Bob", age: 55)') }
            .to raise_error(CompilationError, /Field `name:` was given more than once/)
        end

        it 'rejects kwargs syntax on a regular function call' do
          source = <<~JADE
            module M exposing (f)

            def add(a: Int, b: Int) -> Int
              a + b


            def f -> Int
              add(a: 1, b: 2)
          JADE
          expect { test_compiler.require('m_bad', source) }
            .to raise_error(CompilationError, /Keyword-argument syntax is only valid/)
        end
      end
    end
  end
end
