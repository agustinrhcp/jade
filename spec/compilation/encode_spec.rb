require 'spec_helper'

require 'jade'
require 'jade/module_loader'

module Jade
  describe 'Encode' do
    include_context 'with test compiler'

    context 'primitives' do
      let(:source) do
        <<~JADE
          module Primitives exposing (b, f, i, n, s)

          import Encode


          def s -> String
            Encode.encode_to_string(Encode.string("hello"))


          def i -> String
            Encode.encode_to_string(Encode.int(42))


          def f -> String
            Encode.encode_to_string(Encode.float(3.5))


          def b -> String
            Encode.encode_to_string(Encode.bool(True))


          def n -> String
            Encode.encode_to_string(Encode.null)
        JADE
      end

      before { test_compiler.require('primitives', source) }

      it { expect(Primitives.s).to eql '"hello"' }
      it { expect(Primitives.i).to eql '42' }
      it { expect(Primitives.f).to eql '3.5' }
      it { expect(Primitives.b).to eql 'true' }
      it { expect(Primitives.n).to eql 'null' }
    end

    context 'structural — nullable, list, object' do
      let(:source) do
        <<~JADE
          module Structural exposing (list_of_ints, maybe_nil, maybe_present, person_object)

          import Encode


          def maybe_present -> String
            Encode.encode_to_string(Encode.nullable(Encode.string, Just("x")))


          def maybe_nil -> String
            Encode.encode_to_string(Encode.nullable(Encode.string, Nothing))


          def list_of_ints -> String
            Encode.encode_to_string(Encode.list(Encode.int, [1, 2, 3]))


          def person_object -> String
            pairs = [
              Encode.field("name", Encode.string, "Pepe"),
              Encode.field("age", Encode.int, 30),
            ]

            Encode.encode_to_string(Encode.object(pairs))
        JADE
      end

      before { test_compiler.require('struct', source) }

      it 'nullable Just emits the inner encoding' do
        expect(Structural.maybe_present).to eql '"x"'
      end

      it 'nullable Nothing emits null' do
        expect(Structural.maybe_nil).to eql 'null'
      end

      it 'list emits a JSON array' do
        expect(Structural.list_of_ints).to eql '[1,2,3]'
      end

      it 'object emits a JSON object with declared fields' do
        expect(Structural.person_object).to eql '{"name":"Pepe","age":30}'
      end
    end

    context 'derived Encodable — primitives, Maybe, List, struct' do
      let(:source) do
        <<~JADE
          module Derived exposing (
            int_string,
            list_string,
            maybe_just_string,
            maybe_nothing_string,
            people_string,
            person_string,
            str_string,
          )

          import Encode


          struct Person = {
            name: String,
            age: Int
          }


          def int_string(i: Int) -> String
            Encode.encode_to_string(Encode.encode(i))


          def str_string(s: String) -> String
            Encode.encode_to_string(Encode.encode(s))


          def list_string(xs: List(Int)) -> String
            Encode.encode_to_string(Encode.encode(xs))


          def maybe_just_string(m: Maybe(Int)) -> String
            Encode.encode_to_string(Encode.encode(m))


          def maybe_nothing_string(m: Maybe(Int)) -> String
            Encode.encode_to_string(Encode.encode(m))


          def person_string(p: Person) -> String
            Encode.encode_to_string(Encode.encode(p))


          def people_string(ps: List(Person)) -> String
            Encode.encode_to_string(Encode.encode(ps))
        JADE
      end

      before { test_compiler.require('derived', source) }

      it 'encodes Int' do
        expect(Derived.int_string(42)).to eql '42'
      end

      it 'encodes String' do
        expect(Derived.str_string("hi")).to eql '"hi"'
      end

      it 'encodes List(Int)' do
        expect(Derived.list_string([1, 2, 3])).to eql '[1,2,3]'
      end

      it 'encodes Maybe(Int) Just' do
        expect(Derived.maybe_just_string(7)).to eql '7'
      end

      it 'encodes Maybe(Int) Nothing as null' do
        expect(Derived.maybe_nothing_string(nil)).to eql 'null'
      end

      it 'encodes a struct as a JSON object with declared field names' do
        person = Data.define(:name, :age).new(name: 'Pepe', age: 30)
        expect(Derived.person_string(person)).to eql '{"name":"Pepe","age":30}'
      end

      it 'encodes a list of structs' do
        person = Data.define(:name, :age)
        ps = [person.new(name: 'Pepe', age: 30), person.new(name: 'Lala', age: 25)]
        expect(Derived.people_string(ps)).to eql '[{"name":"Pepe","age":30},{"name":"Lala","age":25}]'
      end
    end

    context 'round-trip with Decode' do
      let(:source) do
        <<~JADE
          module RoundTrip exposing (roundtrip_person)

          import Encode
          import Decode exposing (DecodeError)


          struct Person = {
            name: String,
            age: Int
          }


          def roundtrip_person(p: Person) -> Result(Person, DecodeError)
            json = Encode.encode_to_string(Encode.encode(p))

            Decode.from_json(json)
        JADE
      end

      before { test_compiler.require('round_trip', source) }

      it 'encodes and decodes back to the same struct' do
        person = Data.define(:name, :age).new(name: 'Pepe', age: 30)
        expect(RoundTrip::Internal.roundtrip_person(person))
          .to be_ok(have_attributes(name: 'Pepe', age: 30))
      end
    end

    context 'Encode.encode returns plain Ruby data' do
      let(:source) do
        <<~JADE
          module Boundary exposing (get_user, get_users)

          import Encode
          import Decode exposing (Value)


          struct Person = {
            name: String,
            age: Int
          }


          def get_user -> Value
            Encode.encode(Person("Pepe", 30))


          def get_users -> Value
            Encode.encode([Person("Pepe", 30), Person("Lala", 25)])
        JADE
      end

      before { test_compiler.require('boundary', source) }

      it 'returns a plain Hash to Ruby callers' do
        result = Boundary.get_user
        expect(result).to be_a(Hash)
        expect(result).to eq({ 'name' => 'Pepe', 'age' => 30 })
      end

      it 'returns a plain Array of Hashes to Ruby callers' do
        result = Boundary.get_users
        expect(result).to be_a(Array)
        expect(result).to eq([
          { 'name' => 'Pepe', 'age' => 30 },
          { 'name' => 'Lala', 'age' => 25 },
        ])
      end
    end

    context 'Encode.encode passed as a value (polymorphic fn argument)' do
      let(:source) do
        <<~JADE
          module PolyArg exposing (int_field, object_two, string_field)

          import Encode
          import Decode exposing (Value)


          def string_field(s: String) -> String
            Encode.encode_to_string(
              Encode.object([Encode.field("k", Encode.encode, s)]),
            )


          def int_field(i: Int) -> String
            Encode.encode_to_string(
              Encode.object([Encode.field("k", Encode.encode, i)]),
            )


          def object_two(name: String, age: Int) -> String
            Encode.encode_to_string(
              Encode.object(
                [
                  Encode.field("name", Encode.encode, name),
                  Encode.field("age", Encode.encode, age),
                ],
              ),
            )
        JADE
      end

      before { test_compiler.require('poly_arg', source) }

      it 'wraps Encode.encode with the String dict' do
        expect(PolyArg.string_field("abc")).to eql('{"k":"abc"}')
      end

      it 'wraps Encode.encode with the Int dict' do
        expect(PolyArg.int_field(42)).to eql('{"k":42}')
      end

      it 'wraps each Encode.encode reference with its own dict' do
        expect(PolyArg.object_two("Pepe", 30)).to eql('{"name":"Pepe","age":30}')
      end
    end

    context 'Encode.encode passed to a user fn' do
      let(:source) do
        <<~JADE
          module PolyUserArg exposing (apply_int)

          import Encode
          import Decode exposing (Value)


          def apply_encoder(enc: Int -> Value, i: Int) -> Value
            enc(i)


          def apply_int(i: Int) -> String
            Encode.encode_to_string(apply_encoder(Encode.encode, i))
        JADE
      end

      before { test_compiler.require('poly_user_arg', source) }

      it 'resolves the dict at the user-fn call site' do
        expect(PolyUserArg.apply_int(42)).to eql('42')
      end
    end

    context 'Encode.encode referenced inside a generic body' do
      let(:source) do
        <<~JADE
          module PolyGeneric exposing (wrap_int, wrap_string)

          import Encode
          import Decode exposing (Value)


          def wrap(x: a) -> Value
            Encode.object([Encode.field("v", Encode.encode, x)])


          def wrap_string(s: String) -> String
            Encode.encode_to_string(wrap(s))


          def wrap_int(i: Int) -> String
            Encode.encode_to_string(wrap(i))
        JADE
      end

      before { test_compiler.require('poly_generic', source) }

      it 'threads the dict through the generic call for String' do
        expect(PolyGeneric.wrap_string("abc")).to eql('{"v":"abc"}')
      end

      it 'threads the dict through the generic call for Int' do
        expect(PolyGeneric.wrap_int(7)).to eql('{"v":7}')
      end
    end

    context 'user fn with a constraint passed as a value' do
      let(:source) do
        <<~JADE
          module UserPoly exposing (go_int, go_string)

          import Encode
          import Decode exposing (Value)


          def my_enc(x: a) -> Value
            Encode.encode(x)


          def apply_int(enc: Int -> Value, i: Int) -> Value
            enc(i)


          def apply_string(enc: String -> Value, s: String) -> Value
            enc(s)


          def go_int(i: Int) -> String
            Encode.encode_to_string(apply_int(my_enc, i))


          def go_string(s: String) -> String
            Encode.encode_to_string(apply_string(my_enc, s))
        JADE
      end

      before { test_compiler.require('user_poly', source) }

      it 'specializes the user fn for Int at the value-position use' do
        expect(UserPoly.go_int(42)).to eql('42')
      end

      it 'specializes the user fn for String at the value-position use' do
        expect(UserPoly.go_string("hi")).to eql('"hi"')
      end
    end

    context 'interface method passed as a value' do
      let(:source) do
        <<~JADE
          module IfacePoly exposing (go_int, go_string)

          import Encode
          import Decode exposing (Value)


          def apply_int(enc: Int -> Value, i: Int) -> Value
            enc(i)


          def apply_string(enc: String -> Value, s: String) -> Value
            enc(s)


          def go_int(i: Int) -> String
            Encode.encode_to_string(apply_int(Encode.encoder, i))


          def go_string(s: String) -> String
            Encode.encode_to_string(apply_string(Encode.encoder, s))
        JADE
      end

      before { test_compiler.require('iface_poly', source) }

      it 'resolves the interface method via the Int impl' do
        expect(IfacePoly.go_int(42)).to eql('42')
      end

      it 'resolves the interface method via the String impl' do
        expect(IfacePoly.go_string("hi")).to eql('"hi"')
      end
    end

    context 'user fn and interface method passed as values inside a generic body' do
      let(:source) do
        <<~JADE
          module GenericRef exposing (via_iface_int, via_iface_string, via_user_int, via_user_string)

          import Encode
          import Decode exposing (Value)


          def my_enc(x: a) -> Value
            Encode.encode(x)


          def apply(enc: a -> Value, x: a) -> Value
            enc(x)


          def with_user_fn(x: a) -> Value
            apply(my_enc, x)


          def with_iface(x: a) -> Value
            apply(Encode.encoder, x)


          def via_user_int(i: Int) -> String
            Encode.encode_to_string(with_user_fn(i))


          def via_user_string(s: String) -> String
            Encode.encode_to_string(with_user_fn(s))


          def via_iface_int(i: Int) -> String
            Encode.encode_to_string(with_iface(i))


          def via_iface_string(s: String) -> String
            Encode.encode_to_string(with_iface(s))
        JADE
      end

      before { test_compiler.require('generic_ref', source) }

      it 'user fn as value, dict from enclosing generic, Int caller' do
        expect(GenericRef.via_user_int(42)).to eql('42')
      end

      it 'user fn as value, dict from enclosing generic, String caller' do
        expect(GenericRef.via_user_string("hi")).to eql('"hi"')
      end

      it 'interface method as value, dict from enclosing generic, Int caller' do
        expect(GenericRef.via_iface_int(42)).to eql('42')
      end

      it 'interface method as value, dict from enclosing generic, String caller' do
        expect(GenericRef.via_iface_string("hi")).to eql('"hi"')
      end
    end
  end
end
