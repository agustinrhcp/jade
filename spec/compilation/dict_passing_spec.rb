require 'spec_helper'
require 'jade'
require 'jade/module_loader'

module Jade
  describe 'dictionary passing for polymorphic functions' do
    include_context 'with test compiler'

    it 'attaches constraint when return type wraps the type variable in a struct' do
      test_compiler.require('repro', <<~JADE)
        module Repro exposing(wrapped)

        interface Encoder(a) with
          encode : a -> String
        end

        implements Encoder(Int) with
          encode : encode_int
        end

        def encode_int(n: Int) -> String
          "int"
        end

        struct Box(a) = { value: String, tag: String }

        def wrapped(value: a) -> Box(a)
          Box(encode(value), "tag")
        end
      JADE

      build_root = test_compiler.instance_variable_get(:@build_root)
      compiled = File.read(File.join(build_root, 'repro.rb'))

      expect(compiled).to include('__wrapped__impl__')
      expect(compiled).to include('__dict0__')
    end

    it 'attaches constraints when two where-clauses on the same type variable are used in separate inner calls' do
      test_compiler.require('repro', <<~JADE)
        module Repro exposing(call_both)

        interface A(x) with f : x -> Int end
        interface B(x) with g : x -> Int end

        implements A(Int) with f : f_int end
        implements B(Int) with g : g_int end

        def f_int(n: Int) -> Int 1 end
        def g_int(n: Int) -> Int 2 end
        def add(a: Int, b: Int) -> Int a + b end

        def both(value: x) -> Int
          fx = f(value)
          gx = add(g(value), 0)
          fx + gx
        end

        def call_both() -> Int
          both(42)
        end
      JADE

      build_root = test_compiler.instance_variable_get(:@build_root)
      compiled = File.read(File.join(build_root, 'repro.rb'))

      # call_both is fully concrete — no impl-synthetic wrapper, no dict params.
      expect(compiled).not_to include('__call_both__impl__')

      # And it should run without an arity error.
      expect(Repro.call_both.call).to eql 3
    end

    it 'dispatches encoder when constrained var is nested in an arg constructor' do
      test_compiler.require('repro_nested', <<~JADE)
        module ReproNested exposing(roundtrip, encode_maybe)

        interface Encoder(a) with
          encode : a -> String
        end

        implements Encoder(Int) with
          encode : encode_int
        end

        def encode_int(n: Int) -> String
          "int"
        end

        implements Encoder(Maybe(a)) with
          encode : encode_maybe
        end

        def encode_maybe(m: Maybe(a)) -> String
          case m
          of Just(inner) then encode(inner)
          of Nothing then "nil"
          end
        end

        def roundtrip() -> String
          encode_maybe(Just(42))
        end
      JADE

      # Monomorphic caller: dict resolved at compile time, inlined.
      expect(ReproNested.roundtrip.call).to eql 'int'

      # Polymorphic call from Ruby on Just(Int): wrapper must compute the
      # inner dict (Encoder(Int)) by unboxing the Just, then call the impl.
      expect(ReproNested.encode_maybe.call(Jade::Maybe::Just[42])).to eql 'int'

      # Nothing branch: body doesn't read the inner dict, returns "nil".
      expect(ReproNested.encode_maybe.call(Jade::Maybe::Nothing[])).to eql 'nil'

      # Nested Maybes: Encoder(Maybe(Int)). Dispatch on outer Just must
      # land on encode_maybe again with the inner dict for Encoder(Int).
      expect(ReproNested.encode_maybe.call(Jade::Maybe::Just[Jade::Maybe::Just[42]])).to eql 'int'
    end

    it 'unboxes the constrained var through List, Tuple, nested Maybe, and structs' do
      test_compiler.require('repro_deep', <<~JADE)
        module ReproDeep exposing(encode_list, encode_double, encode_box, encode_tup)

        interface Encoder(a) with
          encode : a -> String
        end

        implements Encoder(Int) with
          encode : encode_int
        end

        def encode_int(n: Int) -> String
          "int"
        end

        implements Encoder(Maybe(a)) with
          encode : encode_maybe
        end

        def encode_maybe(m: Maybe(a)) -> String
          case m
          of Just(inner) then encode(inner)
          of Nothing then "nil"
          end
        end

        def encode_list(xs: List(a)) -> String
          case xs
          of [x | _] then encode(x)
          of [] then "empty"
          end
        end

        def encode_double(mm: Maybe(Maybe(a))) -> String
          case mm
          of Just(inner) then encode_maybe(inner)
          of Nothing then "outer-nothing"
          end
        end

        struct Box(a) = { value: a }

        def encode_box(b: Box(a)) -> String
          encode(b.value)
        end

        def encode_tup(t: (a, Int)) -> String
          case t
          of (x, _) then encode(x)
          end
        end
      JADE

      # List(a) with concrete element type at the Ruby boundary.
      expect(ReproDeep.encode_list.call([42])).to eql 'int'
      expect(ReproDeep.encode_list.call([])).to eql 'empty'

      # Maybe(Maybe(a)) — two unions deep.
      expect(ReproDeep.encode_double.call(Jade::Maybe::Just[Jade::Maybe::Just[42]])).to eql 'int'
      expect(ReproDeep.encode_double.call(Jade::Maybe::Just[Jade::Maybe::Nothing[]])).to eql 'nil'
      expect(ReproDeep.encode_double.call(Jade::Maybe::Nothing[])).to eql 'outer-nothing'

      # Struct field carries the var.
      expect(ReproDeep.encode_box.call(ReproDeep::Box[42])).to eql 'int'

      # Tuple slot carries the var.
      expect(ReproDeep.encode_tup.call(Jade::Tuple::Tuple2[42, 0])).to eql 'int'
    end

    it 'dispatches inner-element dict for List(a) args with a body constraint on a' do
      test_compiler.require('list_show', <<~JADE)
        module ListShow exposing(go)

        interface Show(a) with show : a -> String end
        implements Show(Int) with show : show_int end
        def show_int(n: Int) -> String "n" end

        def join_shows(xs: List(a)) -> String
          xs |> List.map((x) -> { show(x) }) |> String.join(", ")
        end

        def go() -> String
          join_shows([1, 2, 3])
        end
      JADE

      expect(ListShow.go.call).to eql 'n, n, n'
    end

    it 'threads dict for stdlib DerivedFunction calls in polymorphic helpers' do
      test_compiler.require('repro_derived', <<~JADE)
        module ReproDerived exposing (encode_int, encode_str)

        import Encode exposing (encode)
        import Decode exposing (Value)

        def to_value(value: a) -> Value
          encode(value)
        end

        def encode_int(n: Int) -> Value
          to_value(n)
        end

        def encode_str(s: String) -> Value
          to_value(s)
        end
      JADE

      expect(ReproDerived.encode_int.call(42)).to eql 42
      expect(ReproDerived.encode_str.call("hi")).to eql "hi"
    end

    it 'raises a clear error when an unboxable constraint is called from Ruby' do
      test_compiler.require('repro_unsupported', <<~JADE)
        module ReproUnsupported exposing(apply_then_encode, default_value)

        interface Encoder(a) with
          encode : a -> String
        end

        interface Default(a) with
          default : Int -> a
        end

        # Function-typed arg: no witness for `a` extractable from `f` itself.
        def apply_then_encode(f: Int -> a) -> String
          encode(f(0))
        end

        # Var only in return position: no arg to dispatch on.
        def default_value() -> a
          default(0)
        end
      JADE

      expect { ReproUnsupported.apply_then_encode.call(->(_) { 42 }) }
        .to raise_error(
          Jade::Interop::NotCallableFromRuby,
          /Cannot call ReproUnsupported\.apply_then_encode from Ruby/
        )

      expect { ReproUnsupported.default_value.call }
        .to raise_error(
          Jade::Interop::NotCallableFromRuby,
          /does not appear in any argument/
        )
    end
  end
end
