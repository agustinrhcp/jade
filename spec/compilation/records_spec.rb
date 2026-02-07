require 'spec_helper'

require 'jade'
require 'jade/module_loader'

module Jade
  describe 'Recordss' do
    include_context 'with test compiler'

    describe 'record literal' do
      let(:pepe_source) do
        <<~JADE
          module Pepe exposing(person)

          def person() -> { name : String, age : Int }
            { name: "Paul", age: 55 }
          end
        JADE
      end

      it 'generates a person with the right attributes' do
        expect { test_compiler.require('pepe', pepe_source) }.to_not raise_error

        expect(Pepe.person.call()).to have_attributes(name: 'Paul', age: 55)
      end

      context 'when signature does not match' do
        let(:pepe_source) do
          <<~JADE
            module Pepe exposing(person)

            def person() -> { name : String, age : Float }
              { name: "Paul", age: 55 }
            end
          JADE
        end

        it 'fails with type mismatch' do
          expect { test_compiler.require('pepe', pepe_source) }
            .to raise_error(RuntimeError, /it returns { name : String, age : Int } but its signature says it should be { name : String, age : Float }/)
        end
      end

      context 'accessing a field' do
        let(:pepe_source) do
          <<~JADE
            module Pepe exposing(paul, pauls_age)

            def paul() -> { name : String, age : Int }
              { name: "Paul", age: 55 }
            end

            def pauls_age() -> Int
              paul().age
            end
          JADE
        end

        it 'returns the age' do
          expect { test_compiler.require('pepe', pepe_source) }.to_not raise_error

          expect(Pepe.pauls_age.call()).to eql 55
        end

        context 'sugar acces to a' do
          let(:pepe_source) do
            <<~JADE
              module Pepe exposing(paul, pauls_age)

              def paul() -> { name : String, age : Int }
                { name: "Paul", age: 55 }
              end

              def pauls_age() -> Int
                paul() |> .age
              end
            JADE
          end

          it 'returns the age' do
            expect { test_compiler.require('pepe', pepe_source) }.to_not raise_error

            expect(Pepe.pauls_age.call()).to eql 55
          end
        end

        context 'accessing a field that does not exist' do
          let(:pepe_source) do
            <<~JADE
              module Pepe exposing(paul, pauls_age)

              def paul() -> { name : String, age : Int }
                { name: "Paul", age: 55 }
              end

              def pauls_age() -> Int
                paul().ate
              end
            JADE
          end

          it 'fails with type mismatch' do
            expect { test_compiler.require('pepe', pepe_source) }
              .to raise_error(RuntimeError, /it expects { a | ate : Int } but found { name : String, age : Int }>/)
          end
        end
      end

      describe 'updating a field' do
        let(:pepe_source) do
          <<~JADE
            module Pepe exposing(paul, pauls_birthday)

            def paul() -> { name : String, age : Int }
              { name: "Paul", age: 55 }
            end

            def pauls_birthday() -> { name : String, age : Int }
              paul_before_today = paul()
              { paul_before_today | age: paul_before_today.age + 1 }
            end
          JADE
        end

        it 'updates the record' do
          expect { test_compiler.require('pepe', pepe_source) }.to_not raise_error

          expect(Pepe.pauls_birthday.call()).to have_attributes(name: 'Paul', age: 56)
        end
      end

      describe 'updating a field with sugar on top' do
        let(:pepe_source) do
          <<~JADE
            module Pepe exposing(paul, pauls_birthday)

            def paul() -> { name : String, age : Int }
              { name: "Paul", age: 55 }
            end

            def pauls_birthday() -> { name : String, age : Int }
              paul_before_today = paul()
              paul_before_today
                |> .age=(paul_before_today.age + 1)
            end
          JADE
        end

        it 'updates the record' do
          expect { test_compiler.require('pepe', pepe_source) }.to_not raise_error

          expect(Pepe.pauls_birthday.call()).to have_attributes(name: 'Paul', age: 56)
        end
      end

      describe 'with type params' do
        let(:pepe_source) do
          <<~JADE
            module Pepe exposing(pauls_id, franks_id)

            def id(rec: { a | id : id }) -> id
              rec.id
            end

            def pauls_id() -> Int
              { name: "Paul", id: 10 }
                |> id
            end

            def franks_id() -> String
              { name: "Paul", id: "f10" }
                |> id
            end
          JADE
        end

        it 'updates the record' do
          expect { test_compiler.require('pepe', pepe_source) }.to_not raise_error

          expect(Pepe.pauls_id.call()).to eql(10)
          expect(Pepe.franks_id.call()).to eql("f10")
        end
      end
    end

    describe 'struct' do
      let(:pepe_source) do
        <<~JADE
          module Pepe exposing(person)

          struct Person = { name: String, age: Int }

          def person() -> Person
            Person("Paul", 55)
          end
        JADE
      end

      it 'generates a person with the right attributes' do
        expect { test_compiler.require('pepe', pepe_source) }.to_not raise_error

        expect(Pepe.person.call()).to have_attributes(name: 'Paul', age: 55)
      end

      context 'accessor' do
        let(:pepe_source) do
          <<~JADE
            module Pepe exposing(pauls_name)

            struct Person = { name: String, age: Int }

            def named(thing: { a | name : String }) -> String
              thing.name
            end

            def pauls_name() -> String
              Person("Paul", 55) |> named()
            end
          JADE
        end

        it 'generates a person with the right attributes' do
          expect { test_compiler.require('pepe', pepe_source) }.to_not raise_error

          expect(Pepe.pauls_name.call()).to eql('Paul')
        end
      end

      context 'with type params' do
        let(:pepe_source) do
          <<~JADE
            module Pepe exposing(paul, frank, identified)

            struct Person(a) = { name: String, id: a }

            def paul() -> Person(Int)
              Person("Paul", 1)
            end

            def frank() -> Person(String)
              Person("Frank", "f10")
            end

            def identified(ided: { a | id: id }) -> id
              ided.id
            end
          JADE
        end

        it 'generates a person with the right attributes' do
          expect { test_compiler.require('pepe', pepe_source) }.to_not raise_error

          expect(Pepe.paul.call().id).to eql(1)
          expect(Pepe.frank.call().id).to eql('f10')
        end
      end
    end
  end
end
