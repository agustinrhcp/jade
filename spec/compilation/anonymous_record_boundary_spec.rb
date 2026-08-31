require 'spec_helper'

require 'jade'
require 'jade/module_loader'

module Jade
  describe 'an anonymous record at the Ruby boundary' do
    include_context 'with test compiler'

    describe 'as a return type' do
      before { test_compiler.require(source) }

      let(:source) do
        <<~JADE
          module AnonOut exposing (nested, origin)

          def origin -> { x: Int, y: Int }
            { x: 1, y: 2 }
          end


          def nested -> { name: String, at: { x: Int, y: Int } }
            { name: "here", at: { x: 1, y: 2 } }
          end
        JADE
      end

      it 'crosses as a plain hash, the way a struct crosses' do
        expect(AnonOut.origin).to eql({ 'x' => 1, 'y' => 2 })
      end

      it 'encodes a record nested in a record' do
        expect(AnonOut.nested)
          .to eql({ 'name' => 'here', 'at' => { 'x' => 1, 'y' => 2 } })
      end
    end

    describe 'as a field of something else' do
      before { test_compiler.require(source) }

      let(:source) do
        <<~JADE
          module AnonIn exposing (points)

          def points -> List({ x: Int, y: Int })
            [{ x: 1, y: 2 }, { x: 3, y: 4 }]
          end
        JADE
      end

      it 'encodes inside a List' do
        expect(AnonIn.points)
          .to eql [{ 'x' => 1, 'y' => 2 }, { 'x' => 3, 'y' => 4 }]
      end
    end

    describe 'Encode.encode on an anonymous record' do
      before { test_compiler.require(source) }

      let(:source) do
        <<~JADE
          module AnonEncode exposing (to_json)

          import Encode


          def to_json(p: { x: Int, y: Int }) -> String
            Encode.encode_to_string(Encode.encode(p))
          end
        JADE
      end

      it 'derives structurally, with no nominal type to hang an instance on' do
        expect(AnonEncode.to_json({ x: 1, y: 2 })).to eql '{"x":1,"y":2}'
      end
    end

    describe 'a record whose field has no Encodable instance' do
      before { test_compiler.require(source) }

      let(:source) do
        <<~JADE
          module AnonRefuse exposing (Opaque, wrapped)

          type Opaque
            = A
            | B(Int, Int)


          def wrapped -> { tag: Opaque }
            { tag: A }
          end
        JADE
      end

      it 'still refuses at the boundary rather than deriving something wrong' do
        expect { AnonRefuse.wrapped }.to raise_error(Interop::NotExposed)
      end
    end
  end
end
