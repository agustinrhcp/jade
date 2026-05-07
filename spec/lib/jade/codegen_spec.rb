require 'spec_helper'

require 'jade/ast'
require 'jade/frontend'
require 'jade/parsing'
require 'jade/lexer'
require 'jade/codegen'

module Jade
  describe Codegen do
    let(:source) do
      Source.new(uri: 'test', text:)
    end

    let(:generation) do
      Lexer
        .tokenize(source)
        .then { Parsing.parse(it, entry: source.uri) }
        .and_then { |(ast, _)| Frontend.run(ast) }
        .map  { Codegen.generate(*it) }
    end

    subject { generation => Ok(code); code }

    context 'an int literal' do
      let(:text) do
        <<~JADE
          42
        JADE
      end

      it { is_expected.to eql "42" }
    end

    context 'a string literal' do
      let(:text) do
        <<~JADE
          "Pepe"
        JADE
      end

      it { is_expected.to eql '"Pepe"' }
    end

    context 'a boolean literal' do
      let(:text) do
        <<~JADE
          True
        JADE
      end

      it { is_expected.to eql "true" }
    end

    context 'variable binding and reference' do
      let(:text) do
        <<~JADE
          finish = "Hei"
          spanish = "Hola"
          spanish
        JADE
      end

      it { is_expected.to eql "finish = \"Hei\"; spanish = \"Hola\"; spanish" }
    end

    context 'function' do
      let(:text) do
        <<~JADE
          def add(a: Int, b: Int) -> Int
            a
          end
        JADE
      end

      it { is_expected.to eql "def add; ->(a, b) { a }; end" }
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

      it { is_expected.to eql "def add; ->(a, b) { Jade::Runtime.intr('Basics.int_add').call(a, b) }; end; __Test__.add.call(1, 2)" }
    end

    context 'type def' do
      let(:text) do
        <<~JADE
          type Maybe(a) = Just(a) | Nothing
        JADE
      end

      it { is_expected.to eql "Just = Data.define(:_1); Nothing = Data.define" }

      context 'and reference' do
        let(:text) do
          <<~JADE
            type Maybe(a) = Just(a) | Nothing
            Just(12)
          JADE
        end

        subject { super().split('; ') }
        its([0]) { is_expected.to eql "Just = Data.define(:_1)" }
        its([1]) { is_expected.to eql "Nothing = Data.define" }
        its([2]) { is_expected.to eql "__Test__::Just.method(:[]).call(12)" }
      end
    end

    context 'qualified and unqualified references' do
      let(:text) do
        <<~JADE
          def is_empty(str: String) -> Bool
            String.is_empty(str)
          end
        JADE
      end

      it { is_expected.to eql "def is_empty; ->(str) { Jade::Runtime.intr('String.is_empty').call(str) }; end" }
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

      it { is_expected.to include "require 'jade/runtime'; require_relative 'maybe'; require_relative 'result';"}
      it { is_expected.to include "module Test; extend self; def hello; ->(str) { Jade::Runtime.intr('String.is_empty').call(str) }; end; end" }
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

      it { is_expected.to eql "if (Jade::Runtime.intr('String.is_empty').call(\"\")) then; 1; else; 2; end" }
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

      it { is_expected.to eql "case 1; in 1 then 1; in _ then 2; end" }

      context 'with variable binding branches' do
        let(:text) do
          <<~JADE
            case 1
            of 1 then 1
            of x then x
            end
          JADE
        end

        it { is_expected.to eql "case 1; in 1 then 1; in x then x; end" }
      end

      context 'with constructor branches' do
        let(:text) do
          <<~JADE
            type Maybe(a) = Just(a) | Nothing
            case Just(1)
            of Nothing then 0
            of Just(x) then x
            end
          JADE
        end

        it { is_expected.to include "in __Test__::Nothing then 0; in __Test__::Just(x) then x; end" }
      end

      context 'with record pattern' do
        let(:text) do
          <<~JADE
            case { name: "Pepe" }
            of { name: "Pepe" } then True
            of _ then False
            end
          JADE
        end

        it { is_expected.to include 'in { name: "Pepe" } then true' }
      end
    end

    describe 'lambda' do
      let(:text) do
        <<~JADE
          (a, b) -> { a + b }
        JADE
      end

      it { is_expected.to eql "->(a, b) { Jade::Runtime.impl_for(\"Basics.Numeric\", a)[\"(+)\"].call(a, b) }" }

      context 'with a constructor pattern param' do
        let(:text) do
          <<~JADE
            type Box(a) = Box(a)

            fn = (Box(x)) -> { x }
          JADE
        end

        it { is_expected.to include "->(__p0__) { __p0__ => __Test__::Box(x); x }" }
      end

      context 'with a wildcard param' do
        let(:text) do
          <<~JADE
            (_) -> { 42 }
          JADE
        end

        it { is_expected.to eql "->(_) { 42 }" }
      end
    end

    describe 'infix and groupings' do
      subject { super().gsub('Jade::Runtime.intr', '') }

      let(:text) do
        <<~JADE
          1 * 2 + 3 * 4
        JADE
      end

      subject { super().gsub('Jade::Runtime.intr', '') }

      it { is_expected.to eql "('Basics.int_add').call(('Basics.int_mul').call(1, 2), ('Basics.int_mul').call(3, 4))" }

      context 'with grouping' do
        let(:text) do
          <<~JADE
            1 * (2 + 3) * 4
          JADE
        end


        it { is_expected.to eql "('Basics.int_mul').call(('Basics.int_mul').call(1, (('Basics.int_add').call(2, 3))), 4)" }
      end
    end

    describe 'record literal' do
      let(:text) do
        <<~JADE
          { a: "hello", b: 42 }
        JADE
      end

      it { is_expected.to eql "Data.define(:a, :b)[\"hello\", 42]" }
    end

    describe 'record access' do
      let(:text) do
        <<~JADE
          { a: "hello", b: 42 }.a
        JADE
      end

      it { is_expected.to eql "Data.define(:a, :b)[\"hello\", 42].a" }
    end

    describe 'using an interop import' do
      let(:text) do
        <<~JADE
          uses Jade::Date with today: Task(Int, Never)
          end

          def real_today() -> Task(Int, Never)
            today()
          end
        JADE
      end

      it { is_expected.to include "Jade::Runtime.guard(Jade::Date, :today, [\"task\", \"int\", \"never\"]).call()" }
    end

    describe 'struct declaration' do
      let(:text) do
        <<~JADE
          struct Person = { name: String, age: Int }
          Person("Guybrush", 28)
        JADE
      end

      it { is_expected.to eql 'Person = Data.define(:name, :age); __Test__::Person.method(:[]).call("Guybrush", 28)' }
    end

    describe 'tuple' do
      context 'two elements' do
        let(:text) do
          <<~JADE
            (1, 2)
          JADE
        end

        it { is_expected.to eql "Jade::Tuple::Tuple2.method(:[]).call(1, 2)" }
      end

      context 'three elements' do
        let(:text) do
          <<~JADE
            (1, 2, 3)
          JADE
        end

        it { is_expected.to eql "Jade::Tuple::Tuple3.method(:[]).call(1, 2, 3)" }
      end

      context 'four elements' do
        let(:text) do
          <<~JADE
            (1, 2, 3, 4)
          JADE
        end

        it { is_expected.to eql "Jade::Tuple::Tuple4.method(:[]).call(1, 2, 3, 4)" }
      end
    end

    describe 'stdlib with codgen as' do
      context 'with grouping' do
        let(:text) do
          <<~JADE
            not(False)
          JADE
        end


        it { is_expected.to eql "Jade::Runtime.intr('Basics.not').call(false)" }
      end
    end

    describe 'calling a record field that is a function' do
      let(:text) do
        <<~JADE
          record_w_fn = {
            some_fn: (n) -> { n + 2 }
          }

          record_w_fn.some_fn(1)
        JADE
      end

      it { is_expected.to eql "record_w_fn = Data.define(:some_fn)[->(n) { Jade::Runtime.intr('Basics.int_add').call(n, 2) }]; record_w_fn.some_fn.call(1)" }
    end

    describe 'eq constraint' do
      let(:text) do
        <<~JADE
          1 == 2
          False == True
        JADE
      end

      it { is_expected.to eql "Jade::Runtime.intr('Basics.int_eq').call(1, 2); Jade::Runtime.intr('Basics.bool_eq').call(false, true)" }

      context 'using != (free constrained function)' do
        let(:text) do
          <<~JADE
            1 != 2
          JADE
        end

        it { is_expected.to eql "->(impl_arg) { ->(one, other) { !(impl_arg[0]['(==)'].call(one, other)) } }.call([{ \"(==)\" => Jade::Runtime.intr('Basics.int_eq') }]).call(1, 2)" }
      end

      context 'without implementation' do
        context 'for type applications' do
          let(:text) do
            <<~JADE
              def test() -> Bool
                Nothing == Just(1)
              end
            JADE
          end

          it('is derived') { is_expected.to include("impl_arg[0]['(==)'].call(l0, r0)") }
          it { is_expected.to start_with "def test; ->() { ->(impl_arg) { ->(one, other) { " }
          it { is_expected.to end_with ".call(Jade::Maybe::Nothing[], Jade::Maybe::Just.method(:[]).call(1)) }; end" }

          context 'when calling !=' do
            let(:text) do
              <<~JADE
                def test() -> Bool
                  Nothing != Just(1)
                end
              JADE
            end

            it { is_expected.to start_with "def test; ->() { ->(impl_arg) { ->(one, other) { !" }
          end

          context 'with a type with different type params per variant' do
            let(:text) do
              <<~JADE
                def test() -> Bool
                  Ok("OK") != Err(404)
                end
              JADE
            end

            it('is derived') { is_expected.to include("impl_arg[0]['(==)'].call(l0, r0)") }
            it { is_expected.to start_with "def test; ->() { ->(impl_arg) { ->(one, other) { " }
          end
        end

        context 'for anonymous records' do
          let(:text) do
            <<~JADE
              def test() -> Bool
                { salute: "Hola", n: 1 } == { salute: "Hei", n: 2 }
              end
            JADE
          end

          it('is derived') { is_expected.to include("impl_arg[0]['(==)'].call(one.salute, other.salute) && impl_arg[1]['(==)'].call(one.n, other.n)") }
          it { is_expected.to start_with "def test; ->() { ->(impl_arg) { ->(one, other) { " }
          it { is_expected.to end_with ".call(Data.define(:n, :salute)[1, \"Hola\"], Data.define(:n, :salute)[2, \"Hei\"]) }; end" }
        end
      end

      describe 'implementation' do
        context 'with an inline lambda' do
          let(:text) do
            <<~JADE
              type Pepe = Pepe(Int)

              implements Eq(Pepe) with
                (==): (pepe, other_pepe) -> { True }
              end
            JADE
          end

          it 'generates a def wrapping the lambda' do
            is_expected.to include("def __impl_Eq_Pepe_x28x3dx3dx29__; ->(pepe, other_pepe) { true }; end")
          end
        end

        context 'with an inline lambda that dispatches to another interface' do
          let(:text) do
            <<~JADE
              struct Person = { id: Int, name: String }

              implements Eq(Person) with
                (==) : (one, other) -> { one.id == other.id }
              end
            JADE
          end

          it 'generates a def with inlined call site dispatch' do
            is_expected.to include("def __impl_Eq_Person_x28x3dx3dx29__; ->(one, other) { Jade::Runtime.intr('Basics.int_eq').call(one.id, other.id) }; end")
          end
        end

        context 'with a function reference' do
          let(:text) do
            <<~JADE
              type Pepe = Pepe(Int)

              implements Eq(Pepe) with
                (==) : eq_pepe
              end

              def eq_pepe(one: Pepe, other: Pepe) -> Bool
                True
              end
            JADE
          end

          it 'does not generate a def for the implementation' do
            is_expected.not_to include("def __impl_Eq_Pepe")
          end
        end
      end
    end

    describe 'comparable constraint' do
      let(:lt_dict) { "[{ \"compare\" => Jade::Runtime.intr('Basics.int_compare') }]" }

      context '(<)' do
        let(:text) { "1 < 2" }

        it { is_expected.to eql "->(impl_arg) { ->(a, b) { case impl_arg[0]['compare'].call(a, b); in Jade::Basics::LT() then true; in _ then false; end } }.call(#{lt_dict}).call(1, 2)" }
      end

      context '(>)' do
        let(:text) { "1 > 2" }

        it { is_expected.to eql "->(impl_arg) { ->(a, b) { case impl_arg[0]['compare'].call(a, b); in Jade::Basics::GT() then true; in _ then false; end } }.call(#{lt_dict}).call(1, 2)" }
      end

      context '(<=)' do
        let(:text) { "1 <= 2" }

        it { is_expected.to eql "->(impl_arg) { ->(a, b) { case impl_arg[0]['compare'].call(a, b); in Jade::Basics::GT() then false; in _ then true; end } }.call(#{lt_dict}).call(1, 2)" }
      end

      context '(>=)' do
        let(:text) { "1 >= 2" }

        it { is_expected.to eql "->(impl_arg) { ->(a, b) { case impl_arg[0]['compare'].call(a, b); in Jade::Basics::LT() then false; in _ then true; end } }.call(#{lt_dict}).call(1, 2)" }
      end
    end
  end
end
