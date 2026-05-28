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
