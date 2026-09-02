require 'spec_helper'

require 'jade'
require 'jade/module_loader'

module Jade
  # A type may refer to itself; what it needs is one case that does not. This
  # is about the missing case, not about the recursion.
  describe 'A recursive type with nothing to stop it' do
    include_context 'with test compiler'

    def compiling(body)
      -> {
        test_compiler.require(<<~JADE)
          module #{module_name} exposing (go)

          #{body}


          def go -> Int
            1
          end
        JADE
      }
    end

    describe 'rejected' do
      let(:module_name) { 'Uninhabited' }

      def rendered(body)
        compiling(body).call
        nil
      rescue CompilationError => e
        Diagnostics::Renderer.new(colors: false).render_all(e.diagnostics)
      end

      it 'says a type may refer to itself, and how to give this one an end' do
        expect(rendered('struct Pepe = { pepe: Pepe }'))
          .to include('a type may refer to itself')
          .and include('`Maybe(Pepe)` can be `Nothing`')
      end

      it 'tells a union to add a variant rather than to wrap a field' do
        expect(rendered('type T = A(T)'))
          .to include('add a variant that does not mention `T`')
      end

      it 'a struct whose field is itself' do
        expect(&compiling('struct Pepe = { pepe: Pepe }'))
          .to raise_error(/`Pepe` can never be built/)
      end

      it 'a union whose only variant carries itself' do
        expect(&compiling('type T = A(T)'))
          .to raise_error(/`T` can never be built/)
      end

      it 'two structs that need each other' do
        expect(&compiling("struct A = { b: B }\n\n\nstruct B = { a: A }"))
          .to raise_error(/`A` can never be built/)
      end

      it 'two unions that need each other' do
        expect(&compiling("type A = MkA(B)\n\n\ntype B = MkB(A)"))
          .to raise_error(/`A` can never be built/)
      end

      # A tuple is a product with no empty case, unlike the `List` it is
      # written the same way as.
      it 'a struct that reaches itself through a tuple' do
        expect(&compiling('struct Pepe = { pepe: (Int, Pepe) }'))
          .to raise_error(/`Pepe` can never be built/)
      end

      # `Box(a)` is fine on its own; `Box(Q)` is not, and the difference is
      # only visible once the argument is known.
      it 'a struct reaching itself through a wrapper that has no empty case' do
        expect(&compiling("type Box(a) = Box(a)\n\n\nstruct Q = { b: Box(Q) }"))
          .to raise_error(/`Q` can never be built/)
      end
    end

    describe 'accepted' do
      let(:module_name) { 'Inhabited' }

      it 'a union with a base case' do
        expect(&compiling("type T\n  = Base\n  | A(T)")).not_to raise_error
      end

      it 'a struct reaching itself through a Maybe, which has Nothing' do
        expect(&compiling('struct Pepe = { pepe: Maybe(Pepe) }')).not_to raise_error
      end

      it 'a struct reaching itself through a List, which has the empty one' do
        expect(&compiling('struct Pepe = { pepe: List(Pepe) }')).not_to raise_error
      end

      it 'a struct reaching itself through a Result, which has an Err arm' do
        expect(&compiling('struct W = { r: Result(W, String) }')).not_to raise_error
      end

      # You can write one: a function that calls itself. It never returns a
      # `Pepe`, but the function value exists.
      it 'a struct whose field is a function returning itself' do
        expect(&compiling('struct Pepe = { pepe: Int -> Pepe }')).not_to raise_error
      end

      it 'a parameterised type, whose parameter stands for something that exists' do
        expect(&compiling('type Box(a) = Box(a)')).not_to raise_error
      end

      it 'an ordinary struct' do
        expect(&compiling("struct P = {\n  a: Int,\n  b: String\n}")).not_to raise_error
      end
    end

    describe 'a recursive type you can actually build' do
      before do
        test_compiler.require(<<~JADE)
          module RealTree exposing (sample)

          type Tree
            = Leaf
            | Node(Tree, Tree)


          def sample -> Int
            depth(Node(Node(Leaf, Leaf), Leaf))
          end


          def depth(t: Tree) -> Int
            case t
            in Leaf then 0
            in Node(l, r) then 1 + max_of(depth(l), depth(r))
            end
          end


          def max_of(a: Int, b: Int) -> Int
            a > b ? a : b
          end
        JADE
      end

      it 'still compiles and runs' do
        expect(RealTree.sample).to eql 2
      end
    end
  end
end
