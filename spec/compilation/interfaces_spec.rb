require 'spec_helper'

require 'jade'
require 'jade/module_loader'

module Jade
  describe 'Interfaces' do
    include_context 'with test compiler'

    let(:source) do
      <<~JADE
        module InterfaceTest exposing (int_equality, bool_equality, int_inequality)

        def int_equality(int1: Int, int2: Int) -> Bool
          int1 == int2
        end

        def int_inequality(int1: Int, int2: Int) -> Bool
          int1 != int2
        end

        def bool_equality(int1: Bool, int2: Bool) -> Bool
          int1 == int2
        end
      JADE
    end

    it 'returns the value negated' do
      test_compiler.require('interface_test', source)
      expect(InterfaceTest.int_equality.call(1, 2)).to be false
      expect(InterfaceTest.int_equality.call(1, 1)).to be true
      expect(InterfaceTest.int_inequality.call(1, 2)).to be true
      expect(InterfaceTest.int_inequality.call(1, 1)).to be false
      expect(InterfaceTest.bool_equality.call(true, false)).to be false
      expect(InterfaceTest.bool_equality.call(true, true)).to be true
    end

    context 'equality on functions' do
      let(:source) do
        <<~JADE
          module InterfaceTest exposing (fn_equality)

          def fn_equality() -> Bool
            one = (a, b) -> { a + b }
            one == one
          end
        JADE
      end

      it 'fails, because functions cant be compared' do
        expect { test_compiler.require('interface_test', source) }
          .to raise_error(RuntimeError, /Basics.Eq cannot be derived for \(Int, Int\) -> Int/)
      end
    end

    context 'constraint propagation' do
      let(:source) do
        <<~JADE
          module InterfaceTest exposing (compare)

          def compare(a: Int, b: Int) -> Bool
            eq(a, b)
          end

          def eq(a: a, b: a) -> Bool
            a == b
          end
        JADE
      end

      it 'propagates constraints through functions' do
        test_compiler.require('interface_test', source)

        expect(InterfaceTest.compare.call(1, 1)).to be true
      end
    end

    context 'polymorphic equality' do
      let(:source) do
        <<~JADE
          module InterfaceTest exposing (int_eq, bool_eq)

          def poly_eq(a: a, b: a) -> Bool
            a == b
          end

          def int_eq(a: Int, b: Int) -> Bool
            poly_eq(a, b)
          end

          def bool_eq(a: Bool, b: Bool) -> Bool
            poly_eq(a, b)
          end
        JADE
      end

      it 'works for ints and bools' do
        test_compiler.require('interface_test', source)

        expect(InterfaceTest.int_eq.call(1, 1)).to be true
        expect(InterfaceTest.bool_eq.call(true, true)).to be true
      end
    end

    context 'orphan implementation' do
      let(:source) do
        <<~JADE
          module InterfaceTest exposing (int_eq_override)

          implements Eq(Int) with
            (==) : int_eq_override

          def int_eq_override(one: Int, other: Int) -> Bool
            one == other
          end
        JADE
      end

      it 'reports an orphan implementation error' do
        expect { test_compiler.require('interface_test', source) }
          .to raise_error(RuntimeError, /only the owner of the interface or the type/)
      end
    end

    context 'implementation with wrong signature' do
      let(:source) do
        <<~JADE
          module InterfaceTest exposing (pepe_eq)

          type Pepe = Pepe(Int)

          implements Eq(Pepe) with
            (==) : eq_pepe

          def eq_pepe(one: Int, other: Int) -> Bool
            one == other
          end

          def pepe_eq(a: Pepe, b: Pepe) -> Bool
            a == b
          end
        JADE
      end

      it 'reports a type mismatch error' do
        expect { test_compiler.require('interface_test', source) }
          .to raise_error(RuntimeError, /Implementation of Basics\.Eq\.\(==\)/)
      end
    end

    context 'deriving equality' do
      let(:source) do
        <<~JADE
          module InterfaceTest exposing (just_eq, nothing_eq)

          def nothing_eq() -> Bool
            Nothing() == Nothing()
          end

          def just_eq(a: Int, b: Int) -> Bool
            Just(a) == Just(b)
          end
        JADE
      end

      it 'works' do
        test_compiler.require('interface_test', source)

        expect(InterfaceTest.nothing_eq.call()).to be true
        expect(InterfaceTest.just_eq.call(1, 2)).to be false
        expect(InterfaceTest.just_eq.call(1, 1)).to be true
      end
    end

    context 'deriving equality for records' do
      let(:source) do
        <<~JADE
          module InterfaceTest exposing (neq, eq)

          def neq() -> Bool
            { hi: "Hello" } == { hi: "hello" }
          end

          def eq() -> Bool
            { hi: "Hello" } == { hi: "Hello" }
          end
        JADE
      end

      it 'works' do
        test_compiler.require('interface_test', source)

        expect(InterfaceTest.neq.call()).to be false
        expect(InterfaceTest.eq.call()).to be true
      end
    end

    context 'deriving equality for multi-field records' do
      let(:source) do
        <<~JADE
          module InterfaceTest exposing (eq, neq)

          def eq() -> Bool
            { x: 1, y: 2 } == { x: 1, y: 2 }
          end

          def neq() -> Bool
            { x: 1, y: 2 } == { x: 1, y: 3 }
          end
        JADE
      end

      it 'compares all fields' do
        test_compiler.require('interface_test', source)

        expect(InterfaceTest.eq.call()).to be true
        expect(InterfaceTest.neq.call()).to be false
      end
    end

    context 'deriving equality for structs' do
      let(:source) do
        <<~JADE
          module InterfaceTest exposing (eq)

          struct Point = { x: Int, y: Int }

          def eq() -> Bool
            Point(1, 2) == Point(1, 2)
          end
        JADE
      end

      pending 'works (struct == not yet implemented)' do
        test_compiler.require('interface_test', source)

        expect(InterfaceTest.eq.call()).to be true
      end
    end


    context 'equality implementation for structs with inline lambda' do
      let(:source) do
        <<~JADE
          module InterfaceTest exposing (new_person, eq_person)

          struct Person = { id: Int, name: String }

          implements Eq(Person) with
            (==) : (one, other) -> { one.id == other.id }

          def new_person(id: Int, name: String) -> Person
            Person(id, name)
          end

          def eq_person(one: Person, other: Person) -> Bool
            one == other
          end
        JADE
      end

      it 'works' do
        test_compiler.require('interface_test', source)

        person_1 = InterfaceTest.new_person.call(1, "Pepe")
        person_2 = InterfaceTest.new_person.call(2, "Pepe")
        person_3 = InterfaceTest.new_person.call(1, "Lala")

        expect(InterfaceTest.eq_person.call(person_1, person_3)).to be true
        expect(InterfaceTest.eq_person.call(person_2, person_3)).to be false
        expect(InterfaceTest.eq_person.call(person_1, person_2)).to be false
      end
    end

    context 'equality implementation for structs' do
      let(:source) do
        <<~JADE
          module InterfaceTest exposing (new_person, eq_person)

          struct Person = { id: Int, name: String }

          implements Eq(Person) with
            (==) : eq

          def eq(one: Person, other: Person) -> Bool
            one.id == other.id
          end

          def new_person(id: Int, name: String) -> Person
            Person(id, name)
          end

          def eq_person(one: Person, other: Person) -> Bool
            one == other
          end
        JADE
      end

      it 'works' do
        test_compiler.require('interface_test', source)

        person_1 = InterfaceTest.new_person.call(1, "Pepe")
        person_2 = InterfaceTest.new_person.call(2, "Pepe")
        person_3 = InterfaceTest.new_person.call(1, "Lala")

        expect(InterfaceTest.eq_person.call(person_1, person_3)).to be true
        expect(InterfaceTest.eq_person.call(person_2, person_3)).to be false
        expect(InterfaceTest.eq_person.call(person_1, person_2)).to be false
      end
    end
  end
end
