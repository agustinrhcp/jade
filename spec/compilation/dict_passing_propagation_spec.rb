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
  end
end
