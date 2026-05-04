require 'spec_helper'

require 'jade'
require 'jade/module_loader'

module Jade
  describe 'Encode' do
    include_context 'with test compiler'

    context 'primitives' do
      let(:source) do
        <<~JADE
          module Primitives exposing(s, i, f, b, n)

          import Encode

          def s() -> String
            Encode.encode_to_string(Encode.string("hello"))
          end

          def i() -> String
            Encode.encode_to_string(Encode.int(42))
          end

          def f() -> String
            Encode.encode_to_string(Encode.float(3.5))
          end

          def b() -> String
            Encode.encode_to_string(Encode.bool(True))
          end

          def n() -> String
            Encode.encode_to_string(Encode.null)
          end
        JADE
      end

      before { test_compiler.require('primitives', source) }

      it { expect(Primitives.s.call).to eql '"hello"' }
      it { expect(Primitives.i.call).to eql '42' }
      it { expect(Primitives.f.call).to eql '3.5' }
      it { expect(Primitives.b.call).to eql 'true' }
      it { expect(Primitives.n.call).to eql 'null' }
    end

    context 'structural — nullable, list, object' do
      let(:source) do
        <<~JADE
          module Structural exposing(maybe_present, maybe_nil, list_of_ints, person_object)

          import Encode

          def maybe_present() -> String
            Encode.encode_to_string(Encode.nullable(Encode.string, Just("x")))
          end

          def maybe_nil() -> String
            Encode.encode_to_string(Encode.nullable(Encode.string, Nothing))
          end

          def list_of_ints() -> String
            Encode.encode_to_string(Encode.list(Encode.int, [1, 2, 3]))
          end

          def person_object() -> String
            pairs = [Encode.field("name", Encode.string, "Pepe"), Encode.field("age", Encode.int, 30)]
            Encode.encode_to_string(Encode.object(pairs))
          end
        JADE
      end

      before { test_compiler.require('struct', source) }

      it 'nullable Just emits the inner encoding' do
        expect(Structural.maybe_present.call).to eql '"x"'
      end

      it 'nullable Nothing emits null' do
        expect(Structural.maybe_nil.call).to eql 'null'
      end

      it 'list emits a JSON array' do
        expect(Structural.list_of_ints.call).to eql '[1,2,3]'
      end

      it 'object emits a JSON object with declared fields' do
        expect(Structural.person_object.call).to eql '{"name":"Pepe","age":30}'
      end
    end

    context 'derived Encodable — primitives, Maybe, List, struct' do
      let(:source) do
        <<~JADE
          module Derived exposing(int_string, str_string,
                                  list_string, maybe_just_string, maybe_nothing_string,
                                  person_string, people_string)

          import Encode

          struct Person = { name: String, age: Int }

          def int_string(i: Int) -> String
            Encode.encode_to_string(Encode.encode(i))
          end

          def str_string(s: String) -> String
            Encode.encode_to_string(Encode.encode(s))
          end

          def list_string(xs: List(Int)) -> String
            Encode.encode_to_string(Encode.encode(xs))
          end

          def maybe_just_string(m: Maybe(Int)) -> String
            Encode.encode_to_string(Encode.encode(m))
          end

          def maybe_nothing_string(m: Maybe(Int)) -> String
            Encode.encode_to_string(Encode.encode(m))
          end

          def person_string(p: Person) -> String
            Encode.encode_to_string(Encode.encode(p))
          end

          def people_string(ps: List(Person)) -> String
            Encode.encode_to_string(Encode.encode(ps))
          end
        JADE
      end

      before { test_compiler.require('derived', source) }

      it 'encodes Int' do
        expect(Derived.int_string.call(42)).to eql '42'
      end

      it 'encodes String' do
        expect(Derived.str_string.call("hi")).to eql '"hi"'
      end

      it 'encodes List(Int)' do
        expect(Derived.list_string.call([1, 2, 3])).to eql '[1,2,3]'
      end

      it 'encodes Maybe(Int) Just' do
        expect(Derived.maybe_just_string.call(Maybe::Just[7])).to eql '7'
      end

      it 'encodes Maybe(Int) Nothing as null' do
        expect(Derived.maybe_nothing_string.call(Maybe::Nothing[])).to eql 'null'
      end

      it 'encodes a struct as a JSON object with declared field names' do
        person = Data.define(:name, :age).new(name: 'Pepe', age: 30)
        expect(Derived.person_string.call(person)).to eql '{"name":"Pepe","age":30}'
      end

      it 'encodes a list of structs' do
        person = Data.define(:name, :age)
        ps = [person.new(name: 'Pepe', age: 30), person.new(name: 'Lala', age: 25)]
        expect(Derived.people_string.call(ps)).to eql '[{"name":"Pepe","age":30},{"name":"Lala","age":25}]'
      end
    end

    context 'round-trip with Decode' do
      let(:source) do
        <<~JADE
          module RoundTrip exposing(roundtrip_person)

          import Encode
          import Decode exposing(DecodeError)

          struct Person = { name: String, age: Int }

          def roundtrip_person(p: Person) -> Result(Person, DecodeError)
            json = Encode.encode_to_string(Encode.encode(p))
            Decode.from_json(json)
          end
        JADE
      end

      before { test_compiler.require('round_trip', source) }

      it 'encodes and decodes back to the same struct' do
        person = Data.define(:name, :age).new(name: 'Pepe', age: 30)
        result = RoundTrip.roundtrip_person.call(person)
        expect(result).to be_a(Result::Ok)
        expect(result._1).to have_attributes(name: 'Pepe', age: 30)
      end
    end

    context 'Encode.encode returns plain Ruby data' do
      let(:source) do
        <<~JADE
          module Boundary exposing(get_user, get_users)

          import Encode
          import Decode exposing(Value)

          struct Person = { name: String, age: Int }

          def get_user() -> Value
            Encode.encode(Person("Pepe", 30))
          end

          def get_users() -> Value
            Encode.encode([Person("Pepe", 30), Person("Lala", 25)])
          end
        JADE
      end

      before { test_compiler.require('boundary', source) }

      it 'returns a plain Hash to Ruby callers' do
        result = Boundary.get_user.call
        expect(result).to be_a(Hash)
        expect(result).to eq({ 'name' => 'Pepe', 'age' => 30 })
      end

      it 'returns a plain Array of Hashes to Ruby callers' do
        result = Boundary.get_users.call
        expect(result).to be_a(Array)
        expect(result).to eq([
          { 'name' => 'Pepe', 'age' => 30 },
          { 'name' => 'Lala', 'age' => 25 },
        ])
      end
    end
  end
end
