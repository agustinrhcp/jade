require 'spec_helper'

require 'jade'
require 'jade/module_loader'

module Jade
  describe 'Dict-passing constraint propagation through compound shapes' do
    include_context 'with test compiler'

    def shape_source(module_name, body)
      indented_body = body.lines.map.with_index { |l, i| i.zero? ? l : "  #{l}" }.join
      <<~JADE
        module #{module_name} exposing (wrapped)

        interface Encoder(a) with
          encode : a -> String
        end


        implements Encoder(Int) with
          encode: encode_int
        end


        def encode_int(n: Int) -> String
          "int"
        end


        def wrapped(value: a) -> String
          #{indented_body}
        end
      JADE
    end

    def compiled_for(module_name, body)
      test_compiler.require(shape_source(module_name, body))
      test_compiler.generated_source(module_name)
    end

    it 'propagates through a list literal' do
      body = <<~JADE.strip
        [encode(value)]
          |> List.length
          |> (n) -> { "x" }
      JADE
      out = compiled_for('PropList', body)
      expect(out).to include('__wrapped__impl__')
      expect(out).to include('__dict0__')
    end

    it 'propagates through a tuple literal' do
      out = compiled_for('PropTup', '(encode(value), "y") |> (t) -> { "x" }')
      expect(out).to include('__wrapped__impl__')
    end

    it 'propagates through a record literal' do
      body = <<~JADE.strip
        { a: encode(value) } |> (r) -> { r.a }
      JADE
      out = compiled_for('PropRec', body)
      expect(out).to include('__wrapped__impl__')
    end

    it 'propagates through an if-then-else branch' do
      body = <<~JADE.strip
        True ? encode(value) : "x"
      JADE
      out = compiled_for('PropIf', body)
      expect(out).to include('__wrapped__impl__')
    end

    it 'propagates through a case-of branch' do
      body = <<~JADE.strip
        case value
        else encode(value)
        end
      JADE
      out = compiled_for('PropCase', body)
      expect(out).to include('__wrapped__impl__')
    end

    it 'propagates through nested constructor calls (the original 408bcff case)' do
      src = <<~JADE
        module PropStruct exposing (wrapped)

        interface Encoder(a) with
          encode : a -> String
        end


        implements Encoder(Int) with
          encode: encode_int
        end


        def encode_int(n: Int) -> String
          "int"
        end


        struct Box(a) = {
          value: String,
          tag: String
        }


        def wrapped(value: a) -> Box(a)
          Box(encode(value), "tag")
        end
      JADE

      test_compiler.require(src)
      out = test_compiler.generated_source('PropStruct')
      expect(out).to include('__wrapped__impl__')
    end

    it 'propagates through a list inside a struct construction (the original list-bug case)' do
      src = <<~JADE
        module PropListBox exposing (wrapped)

        interface Encoder(a) with
          encode : a -> String
        end


        implements Encoder(Int) with
          encode: encode_int
        end


        def encode_int(n: Int) -> String
          "int"
        end


        struct Box(a) = {
          values: List(String),
          tag: String
        }


        def wrapped(value: a) -> Box(a)
          Box([encode(value)], "tag")
        end
      JADE

      test_compiler.require(src)
      out = test_compiler.generated_source('PropListBox')
      expect(out).to include('__wrapped__impl__')
      expect(out).to include('__dict0__')
    end

    context 'derived constraint over a compound type holding a free var' do
      def decodable_source(module_name, return_type)
        <<~JADE
          module #{module_name} exposing (parse)

          import Decode


          def parse(json: String) -> Result(#{return_type}, Decode.DecodeError)
            Decode.from_json(json)
          end
        JADE
      end

      it 'takes a dict param for the free var inside a List' do
        test_compiler.require(decodable_source('PropDecList', 'List(a)'))
        out = test_compiler.generated_source('PropDecList')
        expect(out).to include('def __parse__impl__(json, __dict0__)')
        expect(out).to include('__dict0__')
      end

      it 'takes a dict param for the free var inside a Maybe' do
        test_compiler.require(decodable_source('PropDecMaybe', 'Maybe(a)'))
        expect(test_compiler.generated_source('PropDecMaybe'))
          .to include('def __parse__impl__(json, __dict0__)')
      end

      it 'takes a dict param for the free var inside an anonymous record' do
        src = <<~JADE
          module PropDecRecord exposing (parse)

          import Decode


          def parse(json: String) -> Result(a, Decode.DecodeError)
            Decode.from_json(json) |> Result.map(value_of)
          end


          def value_of(row: { value: a }) -> a
            row.value
          end
        JADE

        test_compiler.require(src)
        expect(test_compiler.generated_source('PropDecRecord'))
          .to include('def __parse__impl__(json, __dict0__)')
      end

      it 'takes a dict param on the Encodable side too' do
        src = <<~JADE
          module PropEncList exposing (dump)

          import Encode
          import Decode exposing (Value)


          def dump(items: List(a)) -> Value
            Encode.encode(items)
          end
        JADE

        test_compiler.require(src)
        expect(test_compiler.generated_source('PropEncList'))
          .to include('def __dump__impl__(items, __dict0__)')
      end

      it 'threads the caller witness down to the nested dep' do
        src = <<~JADE
          module PropDecCaller exposing (ints, tags)

          import Decode


          def unwrap(json: String) -> Result(a, Decode.DecodeError)
            Decode.from_json(json) |> Result.map(value_of)
          end


          def value_of(row: { value: a }) -> a
            row.value
          end


          def ints(json: String) -> Result(Int, Decode.DecodeError)
            unwrap(json)
          end


          def tags(json: String) -> Result(List(String), Decode.DecodeError)
            unwrap(json)
          end
        JADE

        test_compiler.require(src)

        expect(PropDecCaller::Internal.ints('{"value": 7}')).to eq(Result::Ok[7])
        expect(PropDecCaller::Internal.tags('{"value": ["a", "b"]}'))
          .to eq(Result::Ok[['a', 'b']])
      end

      it 'threads the caller witness down to a nested encoder dep' do
        src = <<~JADE
          module PropEncCaller exposing (dump_ints)

          import Encode
          import Decode exposing (Value)


          def dump(items: List(a)) -> Value
            Encode.encode(items)
          end


          def dump_ints(items: List(Int)) -> Value
            dump(items)
          end
        JADE

        test_compiler.require(src)

        expect(PropEncCaller::Internal.dump_ints([1, 2, 3])).to eq([1, 2, 3])
      end
    end
  end
end
