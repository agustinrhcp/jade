require 'spec_helper'
require 'timeout'

require 'jade'
require 'jade/module_loader'

module Jade
  # A derived instance is built by asking for its components' instances, so a
  # type that contains itself asks for the one being built. Every case here
  # used to exhaust the Ruby stack at compile time.
  describe 'Deriving for a type that contains itself' do
    include_context 'with test compiler'

    describe 'equality on a recursive union' do
      before { test_compiler.require(source) }

      let(:source) do
        <<~JADE
          module TreeEq exposing (deep_diff, deep_same, different_nodes, same_leaves, same_nodes)

          type Tree
            = Leaf
            | Node(Tree, Tree)


          def same_leaves -> Bool
            Leaf == Leaf
          end


          def same_nodes -> Bool
            Node(Leaf, Leaf) == Node(Leaf, Leaf)
          end


          def different_nodes -> Bool
            Node(Leaf, Leaf) == Leaf
          end


          def deep_same -> Bool
            Node(Node(Leaf, Leaf), Leaf) == Node(Node(Leaf, Leaf), Leaf)
          end


          def deep_diff -> Bool
            Node(Node(Leaf, Leaf), Leaf) == Node(Leaf, Node(Leaf, Leaf))
          end
        JADE
      end

      it 'compares the shallow cases' do
        expect(TreeEq.same_leaves).to be true
        expect(TreeEq.same_nodes).to be true
        expect(TreeEq.different_nodes).to be false
      end

      it 'compares all the way down' do
        expect(TreeEq.deep_same).to be true
        expect(TreeEq.deep_diff).to be false
      end
    end

    # Equality falls back to Ruby's `==`, and that is only right because a
    # hand-written `implements Eq` emits a real `==` on the Ruby class — so
    # `Data#==` on the outer value dispatches to it rather than comparing
    # members structurally behind its back.
    describe 'a component of a recursive union with its own equality' do
      before { test_compiler.require(source) }

      let(:source) do
        <<~JADE
          module CustomEq exposing (Tag, deep, ignores_note, shallow, tag_eq)

          struct Tag = {
            id: Int,
            note: String
          }


          implements Eq(Tag) with
            (==): tag_eq
          end


          def tag_eq(a: Tag, b: Tag) -> Bool
            a.id == b.id
          end


          type Tree
            = Leaf(Tag)
            | Node(Tree, Tree)


          def ignores_note -> Bool
            Tag(1, "x") == Tag(1, "y")
          end


          def shallow -> Bool
            Leaf(Tag(1, "x")) == Leaf(Tag(1, "y"))
          end


          def deep -> Bool
            Node(Leaf(Tag(1, "x")), Leaf(Tag(2, "p"))) == Node(Leaf(Tag(1, "y")), Leaf(Tag(2, "q")))
          end
        JADE
      end

      it 'uses that equality, not a structural comparison of the fields' do
        expect(CustomEq.ignores_note).to be true
        expect(CustomEq.shallow).to be true
        expect(CustomEq.deep).to be true
      end
    end

    describe 'a struct that reaches itself through a Maybe' do
      let(:source) do
        <<~JADE
          module RecStruct exposing (depth_of_two, empty)

          struct Pepe = { pepe: Maybe(Pepe) }


          def empty -> Pepe
            Pepe(Nothing)
          end


          def depth_of_two -> Int
            depth(Pepe(Just(Pepe(Nothing))))
          end


          def depth(p: Pepe) -> Int
            case p.pepe
            in Just(inner) then 1 + depth(inner)
            in Nothing then 0
            end
          end
        JADE
      end

      before { test_compiler.require(source) }

      it 'is a perfectly good type inside Jade' do
        expect(RecStruct.depth_of_two).to eql 1
      end

      it 'says so rather than crossing, since no encoder can be derived' do
        expect { RecStruct.empty }
          .to raise_error(Interop::NotExposed, /has no Encodable instance/)
      end
    end

    describe 'asking for a derived decoder by hand' do
      let(:source) do
        <<~JADE
          module RecDecode exposing (parse)

          import Decode


          struct Pepe = { pepe: Maybe(Pepe) }


          def parse(s: String) -> Int
            case Decode.from_json(s)
            in Ok(p) then depth(p)
            in Err(_) then -1
            end
          end


          def depth(p: Pepe) -> Int
            case p.pepe
            in Just(inner) then 1 + depth(inner)
            in Nothing then 0
            end
          end
        JADE
      end

      it 'names the type and points at the way out' do
        expect { test_compiler.require(source) }
          .to raise_error(
            CompilationError,
            /Decode.Decodable cannot be derived for Pepe because it contains itself/,
          )
      end
    end

    describe 'a type that does not contain itself' do
      before { test_compiler.require(source) }

      let(:source) do
        <<~JADE
          module StillFine exposing (pairs, tagged)

          import Encode


          struct Pair = {
            a: Int,
            b: Int
          }


          type Colour
            = Red
            | Tagged(Int)


          def pairs -> Bool
            Pair(1, 2) == Pair(1, 2)
          end


          def tagged -> Bool
            Tagged(1) == Red
          end
        JADE
      end

      # Two fields of one type ask for the same instance twice, side by side
      # rather than nested. Cutting on the wrong signal would break this.
      it 'derives as it always did' do
        expect(StillFine.pairs).to be true
        expect(StillFine.tagged).to be false
      end
    end
  end
end
