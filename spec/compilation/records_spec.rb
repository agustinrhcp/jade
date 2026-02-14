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
    end
  end
end
