require 'spec_helper'
require 'jade'
require 'jade/module_loader'

module Jade
  describe 'dictionary passing for polymorphic functions' do
    include_context 'with test compiler'

    it 'attaches constraint when return type wraps the type variable in a struct' do
      test_compiler.require('repro', <<~JADE)
        module Repro exposing (wrapped)

        interface Encoder(a) with
          encode : a -> String


        implements Encoder(Int) with
          encode: encode_int


        def encode_int(n: Int) -> String
          "int"


        struct Box(a) = {
          value: String,
          tag: String
        }


        def wrapped(value: a) -> Box(a)
          Box(encode(value), "tag")
      JADE

      build_root = test_compiler.instance_variable_get(:@build_root)
      compiled = File.read(File.join(build_root, 'repro.rb'))

      expect(compiled).to include('__wrapped__impl__')
      expect(compiled).to include('__dict0__')
    end

    it 'attaches constraints when two where-clauses on the same type variable are used in separate inner calls' do
      test_compiler.require('repro', <<~JADE)
        module Repro exposing (call_both)

        interface A(x) with
          f : x -> Int


        interface B(x) with
          g : x -> Int


        implements A(Int) with
          f: f_int


        implements B(Int) with
          g: g_int


        def f_int(n: Int) -> Int
          1


        def g_int(n: Int) -> Int
          2


        def add(a: Int, b: Int) -> Int
          a + b


        def both(value: x) -> Int
          fx = f(value)
          gx = add(g(value), 0)

          fx + gx


        def call_both -> Int
          both(42)
      JADE

      build_root = test_compiler.instance_variable_get(:@build_root)
      compiled = File.read(File.join(build_root, 'repro.rb'))

      # call_both is fully concrete — no impl-synthetic wrapper, no dict params.
      expect(compiled).not_to include('__call_both__impl__')

      # And it should run without an arity error.
      expect(Repro.call_both).to eql 3
    end

    it 'dispatches encoder when constrained var is nested in an arg constructor' do
      test_compiler.require('repro_nested', <<~JADE)
        module ReproNested exposing (encode_maybe, roundtrip)

        interface Encoder(a) with
          encode : a -> String


        implements Encoder(Int) with
          encode: encode_int


        def encode_int(n: Int) -> String
          "int"


        implements Encoder(Maybe(a)) with
          encode: encode_maybe


        def encode_maybe(m: Maybe(a)) -> String
          case m
          of Just(inner) -> encode(inner)
          of Nothing -> "nil"


        def roundtrip -> String
          encode_maybe(Just(42))
      JADE

      expect(ReproNested.roundtrip).to eql 'int'
    end

    it 'unboxes the constrained var through List, Tuple, nested Maybe, and structs' do
      test_compiler.require('repro_deep', <<~JADE)
        module ReproDeep exposing (encode_box, encode_double, encode_list, encode_tup)

        interface Encoder(a) with
          encode : a -> String


        implements Encoder(Int) with
          encode: encode_int


        def encode_int(n: Int) -> String
          "int"


        implements Encoder(Maybe(a)) with
          encode: encode_maybe


        def encode_maybe(m: Maybe(a)) -> String
          case m
          of Just(inner) -> encode(inner)
          of Nothing -> "nil"


        def encode_list(xs: List(a)) -> String
          case xs
          of [x | _] -> encode(x)
          of [] -> "empty"


        def encode_double(mm: Maybe(Maybe(a))) -> String
          case mm
          of Just(inner) -> encode_maybe(inner)
          of Nothing -> "outer-nothing"


        struct Box(a) = { value: a }


        def encode_box(b: Box(a)) -> String
          encode(b.value)


        def encode_tup(t: (a, Int)) -> String
          case t
          of (x, _) -> encode(x)
      JADE

      expect(ReproDeep::Internal.respond_to?(:__encode_list__impl__)).to be true
      expect(ReproDeep::Internal.respond_to?(:__encode_double__impl__)).to be true
      expect(ReproDeep::Internal.respond_to?(:__encode_box__impl__)).to be true
      expect(ReproDeep::Internal.respond_to?(:__encode_tup__impl__)).to be true
    end

    it 'dispatches inner-element dict for List(a) args with a body constraint on a' do
      test_compiler.require('list_show', <<~JADE)
        module ListShow exposing (go)

        interface Show(a) with
          show : a -> String


        implements Show(Int) with
          show: show_int


        def show_int(n: Int) -> String
          "n"


        def join_shows(xs: List(a)) -> String
          xs
            |> List.map((x) -> { show(x) })
            |> String.join(", ")


        def go -> String
          join_shows([1, 2, 3])
      JADE

      expect(ListShow.go).to eql 'n, n, n'
    end

    it 'threads dict for stdlib DerivedFunction calls in polymorphic helpers' do
      test_compiler.require('repro_derived', <<~JADE)
        module ReproDerived exposing (encode_int, encode_str)

        import Encode exposing (encode)
        import Decode exposing (Value)


        def to_value(value: a) -> Value
          encode(value)


        def encode_int(n: Int) -> Value
          to_value(n)


        def encode_str(s: String) -> Value
          to_value(s)
      JADE

      expect(ReproDerived.encode_int(42)).to eql 42
      expect(ReproDerived.encode_str("hi")).to eql "hi"
    end

    it 'compiles polymorphic fns with unboxable constraints but exposes no Ruby boundary' do
      test_compiler.require('repro_unsupported', <<~JADE)
        module ReproUnsupported exposing (apply_then_encode, default_value)

        interface Encoder(a) with
          encode : a -> String


        interface Default(a) with
          default : Int -> a


        # Function-typed arg: no witness for `a` extractable from `f` itself.
        def apply_then_encode(f: Int -> a) -> String
          encode(f(0))


        # Var only in return position: no arg to dispatch on.
        def default_value -> a
          default(0)
      JADE

      expect { ReproUnsupported.apply_then_encode(->(_) { 42 }) }
        .to raise_error(
          Jade::Interop::NotExposed,
          /ReproUnsupported\.apply_then_encode is not exposed to Ruby.*polymorphic/,
        )

      expect { ReproUnsupported.default_value }
        .to raise_error(
          Jade::Interop::NotExposed,
          /ReproUnsupported\.default_value is not exposed to Ruby.*polymorphic/,
        )
    end
  end
end
