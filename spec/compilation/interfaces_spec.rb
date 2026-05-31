require 'spec_helper'

require 'jade'
require 'jade/module_loader'

module Jade
  describe 'Interfaces' do
    include_context 'with test compiler'

    let(:source) do
      <<~JADE
        module InterfaceTest exposing (bool_equality, int_equality, int_inequality)

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
      expect(InterfaceTest.int_equality(1, 2)).to be false
      expect(InterfaceTest.int_equality(1, 1)).to be true
      expect(InterfaceTest.int_inequality(1, 2)).to be true
      expect(InterfaceTest.int_inequality(1, 1)).to be false
      expect(InterfaceTest.bool_equality(true, false)).to be false
      expect(InterfaceTest.bool_equality(true, true)).to be true
    end

    context 'equality on functions' do
      let(:source) do
        <<~JADE
          module InterfaceTest exposing (fn_equality)

          def fn_equality -> Bool
            one = (a, b) -> { a + b }
            one == one
          end
        JADE
      end

      it 'fails, because functions cant be compared' do
        expect { test_compiler.require('interface_test', source) }
          .to raise_error(CompilationError, /Basics.Eq cannot be derived for .+ -> /)
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

        expect(InterfaceTest.compare(1, 1)).to be true
      end
    end

    context 'polymorphic equality' do
      let(:source) do
        <<~JADE
          module InterfaceTest exposing (bool_eq, int_eq)

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

        expect(InterfaceTest.int_eq(1, 1)).to be true
        expect(InterfaceTest.bool_eq(true, true)).to be true
      end

      it 'dispatches Jade-internal polymorphic calls without consulting IMPLEMENTATIONS' do
        test_compiler.require('interface_test', source)

        impl_for_calls = 0
        Jade::Runtime.singleton_class.prepend(Module.new {
          define_method(:impl_for) { |*a| impl_for_calls += 1; super(*a) }
        })

        # int_eq calls poly_eq with a dict it builds inline — no impl_for needed
        InterfaceTest.int_eq(1, 1)
        expect(impl_for_calls).to eq 0
      end
    end

    context 'orphan implementation' do
      let(:source) do
        <<~JADE
          module InterfaceTest exposing (int_eq_override)

          implements Eq(Int) with
            (==): int_eq_override
          end


          def int_eq_override(one: Int, other: Int) -> Bool
            one == other
          end
        JADE
      end

      it 'reports an orphan implementation error' do
        expect { test_compiler.require('interface_test', source) }
          .to raise_error(CompilationError, /only the owner of the interface or the type/)
      end
    end

    context 'implementation with wrong signature' do
      let(:source) do
        <<~JADE
          module InterfaceTest exposing (pepe_eq)

          type Pepe = Pepe(Int)


          implements Eq(Pepe) with
            (==): eq_pepe
          end


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
          .to raise_error(CompilationError, /Implementation of Basics\.Eq\.\(==\)/)
      end
    end

    context 'deriving equality' do
      let(:source) do
        <<~JADE
          module InterfaceTest exposing (just_eq, nothing_eq)

          def nothing_eq -> Bool
            Nothing == Nothing
          end


          def just_eq(a: Int, b: Int) -> Bool
            Just(a) == Just(b)
          end
        JADE
      end

      it 'works' do
        test_compiler.require('interface_test', source)

        expect(InterfaceTest.nothing_eq()).to be true
        expect(InterfaceTest.just_eq(1, 2)).to be false
        expect(InterfaceTest.just_eq(1, 1)).to be true
      end
    end

    context 'deriving equality for records' do
      let(:source) do
        <<~JADE
          module InterfaceTest exposing (eq, neq)

          def neq -> Bool
            { hi: "Hello" } == { hi: "hello" }
          end


          def eq -> Bool
            { hi: "Hello" } == { hi: "Hello" }
          end
        JADE
      end

      it 'works' do
        test_compiler.require('interface_test', source)

        expect(InterfaceTest.neq()).to be false
        expect(InterfaceTest.eq()).to be true
      end
    end

    context 'deriving equality for multi-field records' do
      let(:source) do
        <<~JADE
          module InterfaceTest exposing (eq, neq)

          def eq -> Bool
            {
              x: 1,
              y: 2,
            } == {
              x: 1,
              y: 2,
            }
          end


          def neq -> Bool
            {
              x: 1,
              y: 2,
            } == {
              x: 1,
              y: 3,
            }
          end
        JADE
      end

      it 'compares all fields' do
        test_compiler.require('interface_test', source)

        expect(InterfaceTest.eq()).to be true
        expect(InterfaceTest.neq()).to be false
      end
    end

    context 'deriving equality for structs' do
      let(:source) do
        <<~JADE
          module InterfaceTest exposing (eq)

          struct Point = {
            x: Int,
            y: Int
          }


          def eq -> Bool
            Point(1, 2) == Point(1, 2)
          end
        JADE
      end

      it 'works' do
        test_compiler.require('interface_test', source)

        expect(InterfaceTest.eq()).to be true
      end

      context 'when a field has no Eq impl' do
        let(:source) do
          <<~JADE
            module InterfaceTest exposing (eq)

            struct Box = { f: Int -> Int }


            def eq(a: Box, b: Box) -> Bool
              a == b
            end
          JADE
        end

        it 'reports a derivation failure rather than crashing' do
          expect { test_compiler.require('interface_test', source) }
            .to raise_error(CompilationError, /Basics.Eq cannot be derived for/)
        end
      end
    end


    context 'equality implementation for structs with inline lambda' do
      let(:source) do
        <<~JADE
          module InterfaceTest exposing (eq_person, new_person)

          struct Person = {
            id: Int,
            name: String
          }


          implements Eq(Person) with
            (==): (one, other) -> { one.id == other.id }
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

        person_1 = InterfaceTest.new_person(1, "Pepe")
        person_2 = InterfaceTest.new_person(2, "Pepe")
        person_3 = InterfaceTest.new_person(1, "Lala")

        expect(InterfaceTest.eq_person(person_1, person_3)).to be true
        expect(InterfaceTest.eq_person(person_2, person_3)).to be false
        expect(InterfaceTest.eq_person(person_1, person_2)).to be false
      end
    end

    context 'equality implementation for structs' do
      let(:source) do
        <<~JADE
          module InterfaceTest exposing (eq_person, new_person)

          struct Person = {
            id: Int,
            name: String
          }


          implements Eq(Person) with
            (==): eq
          end


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

        person_1 = InterfaceTest.new_person(1, "Pepe")
        person_2 = InterfaceTest.new_person(2, "Pepe")
        person_3 = InterfaceTest.new_person(1, "Lala")

        expect(InterfaceTest.eq_person(person_1, person_3)).to be true
        expect(InterfaceTest.eq_person(person_2, person_3)).to be false
        expect(InterfaceTest.eq_person(person_1, person_2)).to be false
      end
    end

    context 'comparable implementation for structs' do
      let(:source) do
        <<~JADE
          module InterfaceTest exposing (gt, gte, lt, lte, new_score)

          struct Score = { value: Int }


          implements Eq(Score) with
            (==): score_eq
          end


          implements Comparable(Score) extends Eq with
            compare: score_compare
          end


          def score_eq(one: Score, other: Score) -> Bool
            one.value == other.value
          end


          def score_compare(one: Score, other: Score) -> Ordering
            compare(one.value, other.value)
          end


          def new_score(value: Int) -> Score
            Score(value)
          end


          def lt(a: Score, b: Score) -> Bool
            a < b
          end


          def gt(a: Score, b: Score) -> Bool
            a > b
          end


          def lte(a: Score, b: Score) -> Bool
            a <= b
          end


          def gte(a: Score, b: Score) -> Bool
            a >= b
          end
        JADE
      end

      it 'works' do
        test_compiler.require('interface_test', source)

        low  = InterfaceTest.new_score(1)
        high = InterfaceTest.new_score(5)
        same = InterfaceTest.new_score(1)

        expect(InterfaceTest.lt(low, high)).to  be true
        expect(InterfaceTest.lt(high, low)).to  be false
        expect(InterfaceTest.gt(high, low)).to  be true
        expect(InterfaceTest.gt(low, high)).to  be false
        expect(InterfaceTest.lte(low, same)).to be true
        expect(InterfaceTest.lte(high, low)).to be false
        expect(InterfaceTest.gte(low, same)).to be true
        expect(InterfaceTest.gte(low, high)).to be false
      end
    end
  end
end
