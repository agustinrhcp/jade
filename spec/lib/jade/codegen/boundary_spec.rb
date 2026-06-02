require 'spec_helper'
require 'jade'
require 'jade/codegen/boundary'
require 'jade/module_loader'

module Jade
  describe Codegen::Boundary do
    let(:registry) { Registry.new.with(source_root: []).then { Stdlib.load(it) } }

    let(:int_t)    { Type.int }
    let(:float_t)  { Type.float }
    let(:bool_t)   { Type.bool }
    let(:string_t) { Type.string }
    let(:value_t)  { Type.constructor('Decode.Value').apply([]) }

    let(:never_t)  { Type.constructor('Basics.Never').apply([]) }
    let(:char_t)   { Type.constructor('Char.Char').apply([]) }

    def list_t(inner)  = Type.constructor('List.List').apply([inner])
    def maybe_t(inner) = Type.constructor('Maybe.Maybe').apply([inner])
    def task_t(ok, err) = Type.constructor('Task.Task').apply([ok, err])
    def result_t(ok, err) = Type.constructor('Result.Result').apply([ok, err])
    def tuple_t(*args)  = Type.constructor("Tuple.Tuple#{args.size}").apply(args)
    def dict_t(k, v)   = Type.constructor('Dict.Dict').apply([k, v])
    def fn_t(args, ret) = Type.function(args, ret)

    describe '.decoder_for' do
      it 'maps Int' do
        expect(described_class.decoder_for(int_t, registry))
          .to eql 'Jade::Runtime.intr("Decode.int").call'
      end

      it 'maps Float' do
        expect(described_class.decoder_for(float_t, registry))
          .to eql 'Jade::Runtime.intr("Decode.float").call'
      end

      it 'maps Bool' do
        expect(described_class.decoder_for(bool_t, registry))
          .to eql 'Jade::Runtime.intr("Decode.bool").call'
      end

      it 'maps String' do
        expect(described_class.decoder_for(string_t, registry))
          .to eql 'Jade::Runtime.intr("Decode.string").call'
      end

      it 'maps Decode.Value to Pass-through' do
        expect(described_class.decoder_for(value_t, registry))
          .to eql 'Jade::Decode::Decoder[Jade::Decode::Desc::Pass[]]'
      end

      it 'recurses through List(Int)' do
        expect(described_class.decoder_for(list_t(int_t), registry))
          .to eql 'Jade::Runtime.intr("Decode.list").call(Jade::Runtime.intr("Decode.int").call)'
      end

      it 'recurses through Maybe(String)' do
        expect(described_class.decoder_for(maybe_t(string_t), registry))
          .to eql 'Jade::Runtime.intr("Decode.nullable").call(Jade::Runtime.intr("Decode.string").call)'
      end

      it 'recurses through nested List(Maybe(Int))' do
        expected = 'Jade::Runtime.intr("Decode.list").call(' \
          'Jade::Runtime.intr("Decode.nullable").call(' \
          'Jade::Runtime.intr("Decode.int").call))'

        expect(described_class.decoder_for(list_t(maybe_t(int_t)), registry))
          .to eql expected
      end

      it 'returns nil for a free type var' do
        expect(described_class.decoder_for(Type.var(1, 'a'), registry)).to be_nil
      end

      it 'returns nil for a List with a free inner var' do
        expect(described_class.decoder_for(list_t(Type.var(1, 'a')), registry)).to be_nil
      end

      it 'returns nil for a function type' do
        expect(described_class.decoder_for(fn_t([int_t], int_t), registry)).to be_nil
      end

      it 'returns nil for a user type with no Decodable impl' do
        unknown = Type.constructor('Unknown.Unknown').apply([])
        expect(described_class.decoder_for(unknown, registry)).to be_nil
      end

      it 'returns nil for Char (no Decodable impl yet)' do
        expect(described_class.decoder_for(char_t, registry)).to be_nil
      end

      it 'returns nil for Result(Int, String) (no Decodable impl yet)' do
        expect(described_class.decoder_for(result_t(int_t, string_t), registry))
          .to be_nil
      end

      it 'returns nil for Tuple2(Int, String) (no Decodable impl yet)' do
        expect(described_class.decoder_for(tuple_t(int_t, string_t), registry))
          .to be_nil
      end

      it 'curries Decode.dict with both arm decoders for Dict(String, Int)' do
        expect(described_class.decoder_for(dict_t(string_t, int_t), registry))
          .to eql 'Jade::Runtime.intr("Decode.dict").curry[' \
                  'Jade::Runtime.intr("Decode.string").call][' \
                  'Jade::Runtime.intr("Decode.int").call]'
      end

      it 'returns nil for Task in arg position (Task is a return-only type at the boundary)' do
        expect(described_class.decoder_for(task_t(int_t, string_t), registry))
          .to be_nil
      end
    end

    describe '.encoder_for' do
      it 'maps Int' do
        expect(described_class.encoder_for(int_t, registry))
          .to eql 'Jade::Runtime.intr("Encode.int")'
      end

      it 'maps String' do
        expect(described_class.encoder_for(string_t, registry))
          .to eql 'Jade::Runtime.intr("Encode.string")'
      end

      it 'recurses through List(Int)' do
        expect(described_class.encoder_for(list_t(int_t), registry))
          .to eql 'Jade::Runtime.intr("Encode.list").curry[Jade::Runtime.intr("Encode.int")]'
      end

      it 'maps Decode.Value to identity' do
        expect(described_class.encoder_for(value_t, registry))
          .to eql '->(v) { v }'
      end

      it 'returns nil for free type var' do
        expect(described_class.encoder_for(Type.var(1, 'a'), registry)).to be_nil
      end

      it 'returns a Never encoder for Basics.Never (uninhabited; raises if called)' do
        expect(described_class.encoder_for(never_t, registry))
          .to eql '->(_) { fail "Never arm produced a value" }'
      end

      it 'returns nil for Char (no Encodable impl yet)' do
        expect(described_class.encoder_for(char_t, registry)).to be_nil
      end

      it 'returns nil for Result(Int, String) (no Encodable impl yet)' do
        expect(described_class.encoder_for(result_t(int_t, string_t), registry))
          .to be_nil
      end

      it 'returns nil for Tuple2(Int, String) (no Encodable impl yet)' do
        expect(described_class.encoder_for(tuple_t(int_t, string_t), registry))
          .to be_nil
      end

      it 'curries Encode.dict with both arm encoders for Dict(String, Int)' do
        expect(described_class.encoder_for(dict_t(string_t, int_t), registry))
          .to eql 'Jade::Runtime.intr("Encode.dict").curry[' \
                  'Jade::Runtime.intr("Encode.string")][' \
                  'Jade::Runtime.intr("Encode.int")]'
      end

      it 'returns nil for Task — return-position only, handled via task_arms' do
        expect(described_class.encoder_for(task_t(int_t, string_t), registry))
          .to be_nil
      end
    end

    describe '.return_eligible? for Task' do
      it 'is true for Task(Int, String)' do
        expect(described_class.return_eligible?(task_t(int_t, string_t), registry))
          .to be true
      end

      it 'is true for Task(Int, Never)' do
        expect(described_class.return_eligible?(task_t(int_t, never_t), registry))
          .to be true
      end

      it 'is false when the ok arm has no encoder' do
        expect(described_class.return_eligible?(task_t(char_t, string_t), registry))
          .to be false
      end

      it 'is false when the err arm has no encoder' do
        expect(described_class.return_eligible?(task_t(int_t, char_t), registry))
          .to be false
      end
    end

    describe '.task_arms' do
      it 'returns the [ok_encoder, err_encoder] pair' do
        ok_enc, err_enc = described_class.task_arms(task_t(int_t, string_t), registry)
        expect(ok_enc).to eql 'Jade::Runtime.intr("Encode.int")'
        expect(err_enc).to eql 'Jade::Runtime.intr("Encode.string")'
      end

      it 'pairs Int with the Never encoder' do
        ok_enc, err_enc = described_class.task_arms(task_t(int_t, never_t), registry)
        expect(ok_enc).to eql 'Jade::Runtime.intr("Encode.int")'
        expect(err_enc).to eql '->(_) { fail "Never arm produced a value" }'
      end

      it 'is nil when ok arm is not encodable' do
        expect(described_class.task_arms(task_t(char_t, string_t), registry))
          .to be_nil
      end

      it 'is nil when err arm is not encodable' do
        expect(described_class.task_arms(task_t(int_t, char_t), registry))
          .to be_nil
      end
    end

    describe '.eligible?' do
      it 'is true for Int -> Int' do
        expect(described_class.eligible?(fn_t([int_t], int_t), registry)).to be true
      end

      it 'is true for (Int, String) -> List(Int)' do
        expect(described_class.eligible?(fn_t([int_t, string_t], list_t(int_t)), registry))
          .to be true
      end

      it 'is false when an arg is polymorphic' do
        expect(described_class.eligible?(fn_t([Type.var(1, 'a')], int_t), registry))
          .to be false
      end

      it 'is false when the return is polymorphic' do
        expect(described_class.eligible?(fn_t([int_t], Type.var(1, 'a')), registry))
          .to be false
      end

      it 'is false when an arg is a function (no decoder for function values)' do
        inner_fn = fn_t([int_t], int_t)
        expect(described_class.eligible?(fn_t([inner_fn], int_t), registry)).to be false
      end

      it 'is true for a no-arg fn returning a primitive' do
        expect(described_class.eligible?(fn_t([], int_t), registry)).to be true
      end

      it 'is false for a no-arg fn whose return type is a function' do
        expect(described_class.eligible?(fn_t([], fn_t([int_t], int_t)), registry)).to be false
      end

      it 'is true for Int -> Task(Int, String)' do
        expect(described_class.eligible?(fn_t([int_t], task_t(int_t, string_t)), registry))
          .to be true
      end

      it 'is true for List(Int) -> Task(Int, String) (mixed-arity Task fn)' do
        expect(described_class.eligible?(fn_t([list_t(int_t)], task_t(int_t, string_t)), registry))
          .to be true
      end

      it 'is false for Int -> Task(Int, Char) (err arm not encodable)' do
        expect(described_class.eligible?(fn_t([int_t], task_t(int_t, char_t)), registry))
          .to be false
      end

      it 'is false for Int -> Result(Int, String) (Result not yet encodable)' do
        expect(described_class.eligible?(fn_t([int_t], result_t(int_t, string_t)), registry))
          .to be false
      end
    end

    describe 'with user-declared Decodable impl' do
      include_context 'with test compiler'

      before do
        test_compiler.require('boundary_test', <<~JADE)
          module BoundaryTest exposing (Wrapper, my_decoder)

          import Decode exposing (Decodable, Decoder)


          struct Wrapper = { name: String }


          implements Decodable(Wrapper) with
            decoder: my_decoder
          end


          def my_decoder -> Decoder(Wrapper)
            Decode.map(Decode.field("name", Decode.string), Wrapper)
          end
        JADE
      end

      let(:loaded_registry) do
        ModuleLoader.load(
          test_compiler.instance_variable_get(:@source_root),
          'boundary_test.jd',
        )
      end

      it 'finds the user-declared decoder via registry impl lookup' do
        wrapper_type = Type.constructor('BoundaryTest.Wrapper').apply([])
        expect(described_class.decoder_for(wrapper_type, loaded_registry))
          .to eql 'BoundaryTest::Internal.method(:my_decoder).call'
      end
    end
  end
end
