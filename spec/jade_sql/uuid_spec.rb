require 'spec_helper'

require 'jade'
require 'jade/module_loader'
require 'jade/tasks'
require 'jade/tasks/rspec'
require_relative '../../extensions/jade_sql/lib/jade-sql'

module Jade
  describe 'Sql.Uuid' do
    include_context 'with test compiler'
    include Jade::Tasks::RSpec

    describe 'parse' do
      let(:source) do
        <<~JADE
          module App exposing (parse_bad, parse_good, parse_upper, str_good)

          import Sql.Uuid exposing (Uuid, parse, to_string)


          def parse_good -> Maybe(Uuid)
            parse("550e8400-e29b-41d4-a716-446655440000")
          end


          def parse_bad -> Maybe(Uuid)
            parse("not-a-uuid")
          end


          def parse_upper -> Maybe(Uuid)
            parse("550E8400-E29B-41D4-A716-446655440000")
          end


          def str_good -> String
            case parse("550E8400-E29B-41D4-A716-446655440000")
            in Just(u) then to_string(u)
            in Nothing then ""
            end
          end
        JADE
      end

      before { test_compiler.require('app', source) }

      it 'accepts a canonical 8-4-4-4-12 form' do
        expect(App::Internal.parse_good).to eql Jade::Maybe::Just[Sql::Uuid::Uuid["550e8400-e29b-41d4-a716-446655440000"]]
      end

      it 'rejects a non-uuid string' do
        expect(App::Internal.parse_bad).to eql Jade::Maybe::Nothing[]
      end

      it 'normalises uppercase to lowercase on roundtrip' do
        expect(App::Internal.str_good).to eql "550e8400-e29b-41d4-a716-446655440000"
      end
    end

    describe 'v4 / v7 generation' do
      let(:source) do
        <<~JADE
          module App exposing (gen_v4, gen_v7)

          import Sql.Uuid exposing (Uuid, to_string, v4, v7)


          def gen_v4 -> Task(String, Never)
            u <- v4

            Task.succeed(to_string(u))
          end


          def gen_v7 -> Task(String, Never)
            u <- v7

            Task.succeed(to_string(u))
          end
        JADE
      end

      before { test_compiler.require('app', source) }

      it 'v4 emits the value from the port wrapped as a Uuid' do
        all_calls_to(JadeSql::Uuid::Runtime.generate_v4) do |t, _args|
          t.ok({ "value" => "00000000-0000-4000-8000-000000000000" })
        end

        result = App::Internal.gen_v4.run
        expect(result).to be_ok("00000000-0000-4000-8000-000000000000")
      end

      it 'v7 emits the value from the port wrapped as a Uuid' do
        all_calls_to(JadeSql::Uuid::Runtime.generate_v7) do |t, _args|
          t.ok({ "value" => "00000000-0000-7000-8000-000000000000" })
        end

        result = App::Internal.gen_v7.run
        expect(result).to be_ok("00000000-0000-7000-8000-000000000000")
      end

    end

    describe 'Base64 short form (to_b64 / from_b64)' do
      let(:source) do
        <<~JADE
          module App exposing (
            from_b64_bad,
            from_b64_good,
            from_b64_wrong_size,
            round_trip,
            to_b64_known,
          )

          import Sql.Uuid exposing (Uuid, from_b64, parse, to_b64, to_string)


          def to_b64_known -> String
            case parse("550e8400-e29b-41d4-a716-446655440000")
            in Just(u) then to_b64(u)
            in Nothing then ""
            end
          end


          def round_trip(s: String) -> String
            case parse(s)
            in Just(u)
              case from_b64(to_b64(u))
              in Just(back) then to_string(back)
              in Nothing then "lost"
              end
            in Nothing then "bad-input"
            end
          end


          def from_b64_good -> Maybe(String)
            case from_b64("VQ6EAOKbQdSnFkRmVUQAAA")
            in Just(u) then Just(to_string(u))
            in Nothing then Nothing
            end
          end


          def from_b64_bad -> Maybe(Uuid)
            from_b64("not!base64")
          end


          def from_b64_wrong_size -> Maybe(Uuid)
            from_b64("aGVsbG8")
          end
        JADE
      end

      before { test_compiler.require('app', source) }

      it 'encodes the canonical form to a 22-char url-safe base64 string' do
        result = App::Internal.to_b64_known
        expect(result.length).to eql 22
        expect(result).to match(/\A[A-Za-z0-9_-]+\z/)
      end

      it 'round-trips canonical -> b64 -> canonical' do
        expect(App::Internal.round_trip("550e8400-e29b-41d4-a716-446655440000"))
          .to eql "550e8400-e29b-41d4-a716-446655440000"
        expect(App::Internal.round_trip("00000000-0000-0000-0000-000000000000"))
          .to eql "00000000-0000-0000-0000-000000000000"
        expect(App::Internal.round_trip("ffffffff-ffff-ffff-ffff-ffffffffffff"))
          .to eql "ffffffff-ffff-ffff-ffff-ffffffffffff"
      end

      it 'parses a known b64 form back to the expected canonical Uuid' do
        expect(App::Internal.from_b64_good)
          .to eql Jade::Maybe::Just["550e8400-e29b-41d4-a716-446655440000"]
      end

      it 'rejects non-base64 input' do
        expect(App::Internal.from_b64_bad).to eql Jade::Maybe::Nothing[]
      end

      it 'rejects b64 of the wrong byte length' do
        expect(App::Internal.from_b64_wrong_size).to eql Jade::Maybe::Nothing[]
      end
    end

    describe 'Encodable' do
      let(:source) do
        <<~JADE
          module App exposing (encoded)

          import Sql.Uuid exposing (Uuid, parse)
          import Encode
          import Decode exposing (Value)


          def encoded -> Value
            case parse("550e8400-e29b-41d4-a716-446655440000")
            in Just(u) then Encode.encode(u)
            in Nothing then Encode.null
            end
          end
        JADE
      end

      before { test_compiler.require('app', source) }

      it 'encodes to the lowercase string form' do
        expect(App::Internal.encoded).to eql "550e8400-e29b-41d4-a716-446655440000"
      end
    end
  end
end
