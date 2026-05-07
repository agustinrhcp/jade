require 'spec_helper'

require 'jade'
require 'jade/module_loader'

module Jade
  describe 'Dict-passing constraint propagation through compound shapes' do
    include_context 'with test compiler'

    def shape_source(module_name, body)
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
          #{body}
        end
      JADE
    end

    def compiled_for(module_name, body)
      test_compiler.require(module_name.downcase, shape_source(module_name, body))
      build_root = test_compiler.instance_variable_get(:@build_root)
      File.read(File.join(build_root, "#{module_name.downcase}.rb"))
    end

    it 'propagates through a list literal' do
      out = compiled_for('PropList', '[encode(value)] |> List.length |> (n) -> { "x" }')
      expect(out).to include('__wrapped__impl__')
      expect(out).to include('__dict0__')
    end

    it 'propagates through a tuple literal' do
      out = compiled_for('PropTup', '(encode(value), "y") |> (t) -> { "x" }')
      expect(out).to include('__wrapped__impl__')
    end

    it 'propagates through a record literal' do
      out = compiled_for('PropRec', '{ a: encode(value) } |> (r) -> { r.a }')
      expect(out).to include('__wrapped__impl__')
    end

    it 'propagates through an if-then-else branch' do
      out = compiled_for('PropIf', 'if True then encode(value) else "x" end')
      expect(out).to include('__wrapped__impl__')
    end

    it 'propagates through a case-of branch' do
      out = compiled_for('PropCase', "case value of _ then encode(value) end")
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
          tag: String,
        }

        def wrapped(value: a) -> Box(a)
          Box(encode(value), "tag")
        end
      JADE

      test_compiler.require('propstruct', src)
      build_root = test_compiler.instance_variable_get(:@build_root)
      out = File.read(File.join(build_root, 'propstruct.rb'))
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
          tag: String,
        }

        def wrapped(value: a) -> Box(a)
          Box([encode(value)], "tag")
        end
      JADE

      test_compiler.require('proplistbox', src)
      build_root = test_compiler.instance_variable_get(:@build_root)
      out = File.read(File.join(build_root, 'proplistbox.rb'))
      expect(out).to include('__wrapped__impl__')
      expect(out).to include('__dict0__')
    end
  end
end
