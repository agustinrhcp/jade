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
      test_compiler.require(source)
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
        expect { test_compiler.require(source) }
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
        test_compiler.require(source)

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
        test_compiler.require(source)

        expect(InterfaceTest.int_eq(1, 1)).to be true
        expect(InterfaceTest.bool_eq(true, true)).to be true
      end

      it 'dispatches Jade-internal polymorphic calls without consulting IMPLEMENTATIONS' do
        test_compiler.require(source)

        impl_for_calls = 0
        Jade::Runtime.singleton_class.prepend(Module.new {
          define_method(:impl_for) { |*a| impl_for_calls += 1; super(*a) }
        })

        # int_eq calls poly_eq with a dict it builds inline — no impl_for needed
        InterfaceTest.int_eq(1, 1)
        expect(impl_for_calls).to eq 0
      end
    end

    context 'two implementations for the same head type' do
      let(:source) do
        <<~JADE
          module InterfaceTest exposing (Assignable, Box(..), Cols(..), Val(..), Val2(..), go, to_assigns)

          struct Cols = { name: String }


          struct Val = { name: String }


          struct Val2 = { size: String }


          struct Box(c, a) = { value: a }


          interface Assignable(w) with
            to_assigns : w -> List(String)
          end


          implements Assignable(Box(Cols, Val)) with
            to_assigns: val_assigns
          end


          def val_assigns(w: Box(Cols, Val)) -> List(String)
            [w.value.name]
          end


          implements Assignable(Box(Cols, Val2)) with
            to_assigns: val2_assigns
          end


          def val2_assigns(w: Box(Cols, Val2)) -> List(String)
            [w.value.size]
          end


          def go -> List(String)
            to_assigns(Box(Val("Widget")))
          end
        JADE
      end

      it 'reports the duplicate instead of letting the second win' do
        expect { test_compiler.require(source) }
          .to raise_error(CompilationError, /Duplicate implementation of InterfaceTest.Assignable for InterfaceTest.Box/)
      end
    end

    context 'one interface implemented for two different head types' do
      let(:source) do
        <<~JADE
          module InterfaceTest exposing (Named, Other(..), Pepe(..), names)

          struct Pepe = { name: String }


          struct Other = { title: String }


          interface Named(a) with
            name_of : a -> String
          end


          implements Named(Pepe) with
            name_of: pepe_name
          end


          def pepe_name(p: Pepe) -> String
            p.name
          end


          implements Named(Other) with
            name_of: other_name
          end


          def other_name(o: Other) -> String
            o.title
          end


          def names -> List(String)
            [name_of(Pepe("pepe")), name_of(Other("other"))]
          end
        JADE
      end

      it 'compiles' do
        test_compiler.require(source)

        expect(InterfaceTest.names).to eql ['pepe', 'other']
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
        expect { test_compiler.require(source) }
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
        expect { test_compiler.require(source) }
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
        test_compiler.require(source)

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
        test_compiler.require(source)

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
        test_compiler.require(source)

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
        test_compiler.require(source)

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
          expect { test_compiler.require(source) }
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
        test_compiler.require(source)

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
        test_compiler.require(source)

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
        test_compiler.require(source)

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
    describe 'a witness needed by a function declared later in the file' do
      it 'is forwarded through the caller' do
        test_compiler.require(<<~JADE)
          module Fwd exposing (run)

          def flags(xs: List(a), y: a) -> List(Bool)
            xs |> List.map((x) -> { same(x, y) })
          end


          def same(p: a, q: a) -> Bool
            p == q
          end


          def run -> List(Bool)
            flags([1, 2], 2)
          end
        JADE

        expect(Fwd.run).to eql [false, true]
      end

      it 'is forwarded down a chain of them' do
        test_compiler.require(<<~JADE)
          module Chain exposing (run)

          def top(p: a, q: a) -> Bool
            mid(p, q)
          end


          def mid(p: a, q: a) -> Bool
            bottom(p, q)
          end


          def bottom(p: a, q: a) -> Bool
            p == q
          end


          def run -> List(Bool)
            [top(1, 1), top(1, 2)]
          end
        JADE

        expect(Chain.run).to eql [true, false]
      end
    end

  end
end
