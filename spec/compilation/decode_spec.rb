require 'spec_helper'

require 'jade'
require 'jade/module_loader'

module Jade
  describe 'Decode' do
    include_context 'with test compiler'

    let(:source) do
      <<~JADE
        module Decoding exposing (
          run_field,
          run_int,
          run_list,
          run_map2,
          run_missing,
          run_nullable_nil,
          run_nullable_present,
          run_optional_absent,
          run_optional_present,
          run_string,
          run_wrong_type,
        )

        import Decode exposing (DecodeError)

        struct Point = {
          x: Int,
          y: Int
        }

        def run_string(json: String) -> Result(String, DecodeError)
          Decode.decode_string(Decode.string, json)
        end

        def run_int(json: String) -> Result(Int, DecodeError)
          Decode.decode_string(Decode.int, json)
        end

        def run_field(json: String) -> Result(String, DecodeError)
          Decode.decode_string(Decode.field("name", Decode.string), json)
        end

        def run_missing(json: String) -> Result(String, DecodeError)
          Decode.decode_string(Decode.field("age", Decode.string), json)
        end

        def run_nullable_present(json: String) -> Result(Maybe(String), DecodeError)
          Decode.decode_string(Decode.nullable(Decode.string), json)
        end

        def run_nullable_nil(json: String) -> Result(Maybe(String), DecodeError)
          Decode.decode_string(Decode.nullable(Decode.string), json)
        end

        def run_optional_absent(json: String) -> Result(Maybe(String), DecodeError)
          Decode.decode_string(Decode.optional_field("x", Decode.string), json)
        end

        def run_optional_present(json: String) -> Result(Maybe(String), DecodeError)
          Decode.decode_string(Decode.optional_field("x", Decode.string), json)
        end

        def run_wrong_type(json: String) -> Result(Int, DecodeError)
          Decode.decode_string(Decode.int, json)
        end

        def run_list(json: String) -> Result(List(Int), DecodeError)
          Decode.decode_string(Decode.list(Decode.int), json)
        end

        def run_map2(json: String) -> Result(Point, DecodeError)
          decoder = Decode.succeed(Point(_, _))
            |> Decode.required("x", Decode.int)
            |> Decode.required("y", Decode.int)

          Decode.decode_string(decoder, json)
        end
      JADE
    end

    before { test_compiler.require('decoding', source) }

    it 'decodes a string' do
      expect(Decoding.run_string.call('"hello"')).to be_ok("hello")
    end

    it 'decodes an int' do
      expect(Decoding.run_int.call('42')).to be_ok(42)
    end

    it 'decodes a required field' do
      expect(Decoding.run_field.call('{"name":"Pepe"}')).to be_ok("Pepe")
    end

    it 'returns MissingField for absent required field' do
      expect(Decoding.run_missing.call('{"name":"Pepe"}')).to be_err(Decode::MissingField["age"])
    end

    it 'nullable decodes a present value' do
      expect(Decoding.run_nullable_present.call('"hello"')).to be_ok(be_just("hello"))
    end

    it 'nullable decodes null to Nothing' do
      expect(Decoding.run_nullable_nil.call('null')).to be_ok(be_nothing)
    end

    it 'optional_field returns Nothing for absent key' do
      expect(Decoding.run_optional_absent.call('{}')).to be_ok(be_nothing)
    end

    it 'optional_field returns Just for present key' do
      expect(Decoding.run_optional_present.call('{"x":"hi"}')).to be_ok(be_just("hi"))
    end

    it 'optional_field with null value is an error (key present, wrong type)' do
      expect(Decoding.run_optional_present.call('{"x":null}'))
        .to be_err(be_a(Decode::AtField))
    end

    it 'returns WrongType for type mismatch' do
      expect(Decoding.run_wrong_type.call('"not an int"')).to be_err(Decode::WrongType["Int", "String"])
    end

    it 'decodes a list' do
      expect(Decoding.run_list.call('[1,2,3]')).to be_ok([1, 2, 3])
    end

    it 'map2 decodes multiple fields into a struct' do
      expect(Decoding.run_map2.call('{"x":3,"y":7}'))
        .to be_ok(have_attributes(x: 3, y: 7))
    end

    it 'map2 collects errors from both fields' do
      expect(Decoding.run_map2.call('{}'))
        .to be_err(be_a(Decode::Multiple))
    end

    context 'sequence' do
      let(:source) do
        <<~JADE
          module SeqTest exposing (run_all_ok, run_one_err, run_two_err)

          import Decode exposing (DecodeError)

          def run_all_ok(json: String) -> Result(List(Int), DecodeError)
            decoders = [Decode.field("a", Decode.int), Decode.field("b", Decode.int)]

            Decode.decode_string(Decode.sequence(decoders), json)
          end

          def run_one_err(json: String) -> Result(List(Int), DecodeError)
            decoders = [Decode.field("a", Decode.int), Decode.field("b", Decode.int)]

            Decode.decode_string(Decode.sequence(decoders), json)
          end

          def run_two_err(json: String) -> Result(List(Int), DecodeError)
            decoders = [Decode.field("a", Decode.int), Decode.field("b", Decode.int)]

            Decode.decode_string(Decode.sequence(decoders), json)
          end
        JADE
      end

      before { test_compiler.require('seq_test', source) }

      it 'runs each decoder against the same value and collects results' do
        expect(SeqTest.run_all_ok.call('{"a":1,"b":2}')).to be_ok([1, 2])
      end

      it 'reports the single error when only one decoder fails' do
        expect(SeqTest.run_one_err.call('{"a":1}'))
          .to be_err(be_a(Decode::MissingField))
      end

      it 'wraps multiple errors in Multiple' do
        expect(SeqTest.run_two_err.call('{}'))
          .to be_err(be_a(Decode::Multiple))
      end
    end

    context 'one_of' do
      let(:source) do
        <<~JADE
          module OneOfTest exposing (Id(..), id_from_json)

          import Decode exposing (DecodeError)

          type Id
            = StringId(String)
            | IntId(Int)

          def id_from_json(json: String) -> Result(Id, DecodeError)
            string_id = Decode.map(StringId, Decode.string)
            int_id = Decode.map(IntId, Decode.int)
            decoder = Decode.one_of([string_id, int_id])

            Decode.decode_string(decoder, json)
          end
        JADE
      end

      before { test_compiler.require('one_of_test', source) }

      it 'picks the first matching decoder' do
        expect(OneOfTest.id_from_json.call('"abc"')).to be_ok(OneOfTest::StringId['abc'])
      end

      it 'falls through to the second decoder' do
        expect(OneOfTest.id_from_json.call('42')).to be_ok(OneOfTest::IntId[42])
      end

      it 'collects errors from every branch when all fail' do
        expect(OneOfTest.id_from_json.call('true'))
          .to be_err(be_a(Decode::Multiple))
      end
    end

    context 'pipeline API (succeed / and_map / required / optional)' do
      let(:source) do
        <<~JADE
          module Pipeline exposing (person_from_json, person_with_default_from_json)

          import Decode exposing (DecodeError, Decoder)

          struct Person = {
            name: String,
            age: Int,
            nickname: String
          }

          def person_decoder() -> Decoder(Person)
            Decode.succeed(Person(_, _, _))
              |> Decode.required("name", Decode.string)
              |> Decode.required("age", Decode.int)
              |> Decode.optional("nickname", Decode.string, "anon")
          end

          def person_from_json(json: String) -> Result(Person, DecodeError)
            Decode.decode_string(person_decoder, json)
          end

          def person_with_default_from_json(json: String) -> Result(Person, DecodeError)
            Decode.decode_string(person_decoder, json)
          end
        JADE
      end

      before { test_compiler.require('pipeline', source) }

      it 'decodes a struct via the pipeline' do
        expect(Pipeline.person_from_json.call('{"name":"Pepe","age":30,"nickname":"Pep"}'))
          .to be_ok(have_attributes(name: 'Pepe', age: 30, nickname: 'Pep'))
      end

      it 'uses the default when an optional key is missing' do
        expect(Pipeline.person_from_json.call('{"name":"Pepe","age":30}'))
          .to be_ok(have_attributes(name: 'Pepe', age: 30, nickname: 'anon'))
      end

      it 'uses the default when an optional value is null' do
        expect(Pipeline.person_from_json.call('{"name":"Pepe","age":30,"nickname":null}'))
          .to be_ok(have_attributes(name: 'Pepe', age: 30, nickname: 'anon'))
      end

      it 'fails when a required field is missing' do
        expect(Pipeline.person_from_json.call('{"age":30}')).to be_err
      end

      it 'fails when an optional field has the wrong type' do
        expect(Pipeline.person_from_json.call('{"name":"Pepe","age":30,"nickname":42}'))
          .to be_err
      end
    end

    context 'auto-derived Decodable' do
      let(:source) do
        <<~JADE
          module Derived exposing (
            int_from_json,
            list_from_json,
            maybe_from_json,
            people_from_json,
            person_from_json,
            str_from_json,
          )

          import Decode exposing (DecodeError)

          struct Person = {
            name: String,
            age: Int
          }

          def int_from_json(json: String) -> Result(Int, DecodeError)
            Decode.from_json(json)
          end

          def str_from_json(json: String) -> Result(String, DecodeError)
            Decode.from_json(json)
          end

          def list_from_json(json: String) -> Result(List(Int), DecodeError)
            Decode.from_json(json)
          end

          def maybe_from_json(json: String) -> Result(Maybe(Int), DecodeError)
            Decode.from_json(json)
          end

          def person_from_json(json: String) -> Result(Person, DecodeError)
            Decode.from_json(json)
          end

          def people_from_json(json: String) -> Result(List(Person), DecodeError)
            Decode.from_json(json)
          end
        JADE
      end

      before { test_compiler.require('derived', source) }

      it 'decodes Int' do
        expect(Derived.int_from_json.call('42')).to be_ok(42)
      end

      it 'decodes String' do
        expect(Derived.str_from_json.call('"hi"')).to be_ok('hi')
      end

      it 'decodes List(Int)' do
        expect(Derived.list_from_json.call('[1,2,3]')).to be_ok([1, 2, 3])
      end

      it 'decodes Maybe(Int) — present' do
        expect(Derived.maybe_from_json.call('7')).to be_ok(be_just(7))
      end

      it 'decodes Maybe(Int) — null' do
        expect(Derived.maybe_from_json.call('null')).to be_ok(be_nothing)
      end

      it 'decodes a struct' do
        expect(Derived.person_from_json.call('{"name":"Pepe","age":30}'))
          .to be_ok(have_attributes(name: 'Pepe', age: 30))
      end

      it 'fails on missing struct field' do
        expect(Derived.person_from_json.call('{"name":"Pepe"}')).to be_err
      end

      it 'decodes a list of structs' do
        json = '[{"name":"Pepe","age":30},{"name":"Lala","age":25}]'
        expect(Derived.people_from_json.call(json)).to be_ok(
          contain_exactly(
            have_attributes(name: 'Pepe', age: 30),
            have_attributes(name: 'Lala', age: 25),
          )
        )
      end
    end

    context 'patch body: absent fields decoded into a list of variants' do
      let(:source) do
        <<~JADE
          module Patch exposing (parse_updates)

          import Decode exposing (DecodeError, Value)

          type Update
            = SetName(String)
            | SetAge(Int)

          def name_update(s: String) -> Update
            SetName(s)
          end

          def age_update(a: Int) -> Update
            SetAge(a)
          end

          def to_list(m: Maybe(Update)) -> List(Update)
            case m
            of Just(u) then List.singleton(u)
            of Nothing then []
            end
          end

          def collect(items: List(Maybe(Update))) -> List(Update)
            List.and_then(items, to_list)
          end

          def make_pair(n: Maybe(Update), a: Maybe(Update)) -> List(Update)
            collect([n, a])
          end

          def parse_updates(value: Value) -> Result(List(Update), DecodeError)
            decoder = Decode.succeed(make_pair(_, _))
              |> Decode.and_map(Decode.optional_field("name", Decode.map(name_update, Decode.string)))
              |> Decode.and_map(Decode.optional_field("age", Decode.map(age_update, Decode.int)))

            Decode.decode(decoder, value)
          end
        JADE
      end

      before { test_compiler.require('patch', source) }

      it 'returns an empty list when no fields are present' do
        result = Patch.parse_updates.call({})
        expect(result).to be_ok([])
      end

      it 'collects only the fields that were provided' do
        expect(Patch.parse_updates.call({ name: 'Pepe' }))
          .to be_ok([Patch::SetName['Pepe']])
      end

      it 'collects all fields when all are present' do
        expect(Patch.parse_updates.call({ name: 'Pepe', age: 30 }))
          .to be_ok([Patch::SetName['Pepe'], Patch::SetAge[30]])
      end

      it 'fails when a present field has the wrong type' do
        expect(Patch.parse_updates.call({ name: 42 })).to be_err
      end
    end

    context 'auto-derived Decodable with Maybe field' do
      let(:source) do
        <<~JADE
          module DerivedMaybe exposing (person_from_json)

          import Decode exposing (DecodeError)

          struct Person = {
            name: String,
            nickname: Maybe(String)
          }

          def person_from_json(json: String) -> Result(Person, DecodeError)
            Decode.from_json(json)
          end
        JADE
      end

      before { test_compiler.require('derived_maybe', source) }

      it 'decodes Just when nickname is present' do
        expect(DerivedMaybe.person_from_json.call('{"name":"Pepe","nickname":"Pep"}'))
          .to be_ok(have_attributes(name: 'Pepe', nickname: Jade::Maybe::Just['Pep']))
      end

      it 'decodes Nothing when nickname is null' do
        expect(DerivedMaybe.person_from_json.call('{"name":"Pepe","nickname":null}'))
          .to be_ok(have_attributes(name: 'Pepe', nickname: Jade::Maybe::Nothing[]))
      end

      it 'fails when nickname key is absent (no optional_field magic)' do
        expect(DerivedMaybe.person_from_json.call('{"name":"Pepe"}')).to be_err
      end
    end

    context 'decoding a Value from a port' do
      module TestBodyParser
        extend Jade::Port

        task :get_body do |t|
          t.ok({ name: 'Pepe', age: 30 })
        end
      end

      let(:value_source) do
        <<~JADE
          module ValueDecoding exposing (handle)

          import Decode exposing (DecodeError, Value)

          uses Jade::TestBodyParser with
            get_body : Task(Value, Never)
          end

          struct Person = {
            name: String,
            age: Int
          }

          def handle() -> Task(Person, DecodeError)
            body <- get_body()

            Task.from_result(Decode.from_value(body))
          end
        JADE
      end

      before { test_compiler.require('value_decoding', value_source) }

      it 'decodes a Ruby hash coming through a port' do
        expect(ValueDecoding.handle.call().run)
          .to be_ok(have_attributes(name: 'Pepe', age: 30))
      end
    end
  end
end
