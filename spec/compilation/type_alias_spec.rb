require 'spec_helper'
require 'timeout'

require 'jade'
require 'jade/module_loader'

module Jade
  describe 'Type alias' do
    include_context 'with test compiler'

    describe 'aliasing a primitive' do
      before do
        test_compiler.require(source)
      end

      let(:source) do
        <<~JADE
          module UserId exposing (inc, zero)

          type alias UserId = Int


          def zero -> UserId
            0
          end


          def inc(id: UserId) -> UserId
            id + 1
          end
        JADE
      end

      it 'compiles and treats the alias like the underlying type' do
        expect(UserId.zero).to eql 0
        expect(UserId.inc(41)).to eql 42
      end
    end

    describe 'aliasing a tuple' do
      before do
        test_compiler.require(source)
      end

      let(:source) do
        <<~JADE
          module Points exposing (origin, sum_coords)

          type alias Point = (Int, Int)


          def origin -> Point
            (0, 0)
          end


          def sum_coords(p: Point) -> Int
            Tuple.first(p) + Tuple.second(p)
          end
        JADE
      end

      it 'compiles and the tuple alias unifies with a tuple literal' do
        expect(Points::Internal.origin).to eql Tuple::Tuple2[0, 0]
        expect(Points::Internal.sum_coords(Tuple::Tuple2[3, 4])).to eql 7
      end
    end

    describe 'aliasing an applied generic' do
      before do
        test_compiler.require(source)
      end

      let(:source) do
        <<~JADE
          module LookUp exposing (found, missing)

          type alias UserResult = Result(Int, String)


          def found -> UserResult
            Ok(42)
          end


          def missing -> UserResult
            Err("not found")
          end
        JADE
      end

      it 'aliases resolve through Result and constructors unify' do
        expect(LookUp::Internal.found).to be_ok(42)
        expect(LookUp::Internal.missing).to be_err("not found")
      end
    end

    describe 'parameterised alias' do
      before do
        test_compiler.require(source)
      end

      let(:source) do
        <<~JADE
          module PairModule exposing (mk, swap)

          type alias Pair(a) = (a, a)


          def mk(x: Int, y: Int) -> Pair(Int)
            (x, y)
          end


          def swap(p: Pair(Int)) -> Pair(Int)
            (Tuple.second(p), Tuple.first(p))
          end
        JADE
      end

      it 'type params substitute correctly' do
        expect(PairModule::Internal.mk(1, 2)).to eql Tuple::Tuple2[1, 2]
        expect(PairModule::Internal.swap(Tuple::Tuple2[1, 2])).to eql Tuple::Tuple2[2, 1]
      end
    end

    describe 'record alias crosses the boundary via Encode' do
      before do
        test_compiler.require(source)
      end

      let(:source) do
        <<~JADE
          module UsersEncode exposing (alice)

          type alias User = {
            name: String,
            age: Int
          }


          def alice -> User
            { name: "Alice", age: 30 }
          end
        JADE
      end

      it 'auto-derives Encodable for a record alias' do
        encoded = UsersEncode.alice
        expect(encoded).to eql({ 'name' => 'Alice', 'age' => 30 })
      end
    end

    describe 'record alias crosses the boundary via Decode' do
      before do
        test_compiler.require(source)
      end

      let(:source) do
        <<~JADE
          module UsersDecode exposing (name_of)

          type alias User = {
            name: String,
            age: Int
          }


          def name_of(u: User) -> String
            u.name
          end
        JADE
      end

      it 'auto-derives Decodable for a record alias' do
        expect(UsersDecode.name_of({ 'name' => 'Bob', 'age' => 0 })).to eql 'Bob'
      end
    end

    describe 'record alias supports record update' do
      before do
        test_compiler.require(source)
      end

      let(:source) do
        <<~JADE
          module UserUpdate exposing (bumped)

          type alias User = {
            name: String,
            age: Int
          }


          def bumped -> User
            base = { name: "Alice", age: 30 }

            { base | age: base.age + 1 }
          end
        JADE
      end

      it '`{ u | age: ... }` is a structural record op — alias just names the type' do
        expect(UserUpdate.bumped).to eql({ 'name' => 'Alice', 'age' => 31 })
      end
    end

    describe 'aliasing a function type' do
      before do
        test_compiler.require(source)
      end

      let(:source) do
        <<~JADE
          module Handlers exposing (apply_int)

          type alias IntFn = Int -> Int


          def apply_int(f: IntFn, x: Int) -> Int
            f(x)
          end
        JADE
      end

      it 'aliases a function type and the call typechecks' do
        expect(Handlers::Internal.apply_int(->(x) { x + 1 }, 5)).to eql 6
      end
    end

    describe 'recursive alias is rejected' do
      let(:source) do
        <<~JADE
          module Bad exposing (whatever)

          type alias L = List(L)


          def whatever -> Int
            0
          end
        JADE
      end

      it 'raises a recursive-alias error' do
        expect { test_compiler.require(source) }
          .to raise_error(/recursive/i)
      end
    end

    describe 'alias is exposed and consumed across modules' do
      before do
        test_compiler.require(shared_source)
        test_compiler.require(consumer_source)
      end

      let(:shared_source) do
        <<~JADE
          module SharedTypes exposing (UserId)

          type alias UserId = Int
        JADE
      end

      let(:consumer_source) do
        <<~JADE
          module SharedConsumer exposing (next_id)

          import SharedTypes exposing (UserId)


          def next_id(id: UserId) -> UserId
            id + 1
          end
        JADE
      end

      it 'a cross-module alias resolves and works at the boundary' do
        expect(SharedConsumer.next_id(41)).to eql 42
      end
    end

    describe 'alias inside a struct field' do
      before do
        test_compiler.require(source)
      end

      let(:source) do
        <<~JADE
          module UserWithId exposing (id_of, mk)

          type alias UserId = Int


          struct UserRow = {
            id: UserId,
            name: String
          }


          def mk(id: UserId, name: String) -> UserRow
            UserRow(id, name)
          end


          def id_of(row: UserRow) -> UserId
            row.id
          end
        JADE
      end

      it 'aliases used as struct field types work transparently' do
        row = UserWithId::Internal.mk(7, 'Carol')
        expect(UserWithId::Internal.id_of(row)).to eql 7
      end
    end

    describe 'alias to alias' do
      before do
        test_compiler.require(source)
      end

      let(:source) do
        <<~JADE
          module AliasesChain exposing (plus_one, zero)

          type alias A = Int


          type alias B = A


          def zero -> B
            0
          end


          def plus_one(b: B) -> A
            b + 1
          end
        JADE
      end

      it 'chained aliases unify all the way down' do
        expect(AliasesChain.zero).to eql 0
        expect(AliasesChain.plus_one(5)).to eql 6
      end
    end

    describe 'alias with wrong arity is rejected' do
      let(:source) do
        <<~JADE
          module BadArity exposing (whatever)

          type alias UserId = Int


          def whatever(x: UserId(Int)) -> Int
            x
          end
        JADE
      end

      it 'raises a type-args-mismatch error' do
        expect { test_compiler.require(source) }
          .to raise_error(/UserId.*needs|argument/i)
      end
    end

    describe 'implements on an alias is rejected' do
      let(:source) do
        <<~JADE
          module BadImpl exposing (Show, show)

          interface Show(a) with
            show : a -> String
          end


          type alias UserId = Int


          implements Show(UserId) with
            show: id_show
          end


          def id_show(n: UserId) -> String
            "id"
          end
        JADE
      end

      it 'raises an alias-impl error pointing at struct/type' do
        expect { test_compiler.require(source) }
          .to raise_error(/alias|nominal/i)
      end
    end

    describe 'unbound type variable is rejected' do
      let(:source) do
        <<~JADE
          module BadAlias exposing (whatever)

          type alias Wrong = List(a)


          def whatever -> Int
            0
          end
        JADE
      end

      it 'raises an unbound-type-variable error' do
        expect { test_compiler.require(source) }
          .to raise_error(/unbound/i)
      end
    end

    describe 'a name already taken is reported, in either order' do
      def compile(*sources)
        sources.each { test_compiler.require(it) }
      end

      it 'reports a second alias of the same name' do
        expect {
          test_compiler.require(<<~JADE)
            module TwiceAliased exposing (x)

            type alias A = Int


            type alias A = String


            def x -> Int
              1
            end
          JADE
        }.to raise_error(/`A` is already declared as a type alias/)
      end

      it 'reports a struct declared after an alias' do
        expect {
          test_compiler.require(<<~JADE)
            module AliasThenStruct exposing (x)

            type alias A = Int


            struct A = {
              a: Int,
              b: Int
            }


            def x -> Int
              1
            end
          JADE
        }.to raise_error(/`A` is already declared as a type alias/)
      end

      it 'reports an alias declared after a struct' do
        expect {
          test_compiler.require(<<~JADE)
            module StructThenAlias exposing (x)

            struct A = {
              a: Int,
              b: Int
            }


            type alias A = Int


            def x -> Int
              1
            end
          JADE
        }.to raise_error(/`A` is already declared as a struct/)
      end

      it 'reports a union declared after an alias' do
        expect {
          test_compiler.require(<<~JADE)
            module AliasThenUnion exposing (x)

            type alias A = Int


            type A
              = B
              | C


            def x -> Int
              1
            end
          JADE
        }.to raise_error(/`A` is already declared as a type alias/)
      end

      it 'reports an alias declared after a union' do
        expect {
          test_compiler.require(<<~JADE)
            module UnionThenAlias exposing (x)

            type A
              = B
              | C


            type alias A = Int


            def x -> Int
              1
            end
          JADE
        }.to raise_error(/`A` is already declared as a type/)
      end
    end

    describe 'recursion detection' do
      it 'catches an alias naming itself' do
        expect {
          test_compiler.require(<<~JADE)
            module DirectCycle exposing (x)

            type alias R = R


            def x -> Int
              1
            end
          JADE
        }.to raise_error(/cycle: R -> R/)
      end

      # Both aliases in a mutual cycle find it, and one mistake deserves one
      # error, so the first-declared one reports and the other stays quiet.
      it 'catches two aliases naming each other, once' do
        expect {
          test_compiler.require(<<~JADE)
            module MutualCycle exposing (x)

            type alias M1 = M2


            type alias M2 = M1


            def x -> Int
              1
            end
          JADE
        }.to raise_error { |e|
          expect(e.message).to include('cycle: M1 -> M2 -> M1')
          expect(e.message).not_to include('cycle: M2 -> M1 -> M2')
        }
      end

      it 'reports from the first declaration, not the first name' do
        expect {
          test_compiler.require(<<~JADE)
            module ReversedCycle exposing (x)

            type alias Z = Y


            type alias Y = Z


            def x -> Int
              1
            end
          JADE
        }.to raise_error { |e|
          expect(e.message).to include('cycle: Z -> Y -> Z')
          expect(e.message).not_to include('cycle: Y -> Z -> Y')
        }
      end

      it 'still reports two separate cycles separately' do
        expect {
          test_compiler.require(<<~JADE)
            module TwoCycles exposing (x)

            type alias M = N


            type alias N = M


            type alias J = K


            type alias K = J


            def x -> Int
              1
            end
          JADE
        }.to raise_error { |e|
          expect(e.message).to include('cycle: M -> N -> M')
          expect(e.message).to include('cycle: J -> K -> J')
        }
      end

      it 'catches a cycle through a record field' do
        expect {
          test_compiler.require(<<~JADE)
            module RecordCycle exposing (x)

            type alias Rec = { self: Rec }


            def x -> Int
              1
            end
          JADE
        }.to raise_error(/cycle: Rec -> Rec/)
      end

      # A union may name itself; only the alias arm of the walk is a cycle.
      # Without this the detector is free to over-fire and nobody notices.
      it 'leaves an alias over a recursive union alone' do
        expect {
          test_compiler.require(<<~JADE)
            module UnionMediated exposing (leaf)

            type Tree
              = Leaf
              | Node(Tree, Tree)


            type alias Forest = List(Tree)


            type alias Pair = (Forest, Forest)


            def leaf -> Tree
              Leaf
            end
          JADE
        }.not_to raise_error
      end

      # Path-sensitive walking made this exponential: 20-odd of these took
      # minutes. It is the runtime, not the answer, that is under test.
      it 'stays cheap when an alias names another one twice' do
        chain = (1..24).map { "type alias A#{it} = (A#{it - 1}, A#{it - 1})" }

        expect {
          Timeout.timeout(20) do
            test_compiler.require(<<~JADE)
              module WideChain exposing (x)

              type alias A0 = Int


              #{chain.join("\n\n\n")}


              def x -> Int
                1
              end
            JADE
          end
        }.not_to raise_error
      end
    end

    describe 'an alias has no constructors to expose' do
      it 'rejects `(..)` on the declaring side' do
        expect {
          test_compiler.require(<<~JADE)
            module ExposeDots exposing (UserId(..), x)

            type alias UserId = Int


            def x -> UserId
              1
            end
          JADE
        }.to raise_error(/`UserId` is a type alias, so `\(\.\.\)` has nothing to expose/)
      end

      it 'rejects `(..)` on the importing side' do
        test_compiler.write(<<~JADE)
          module PlainAlias exposing (UserId)

          type alias UserId = Int
        JADE

        expect {
          test_compiler.require(<<~JADE)
            module ImportsDots exposing (x)

            import PlainAlias exposing (UserId(..))


            def x -> Int
              1
            end
          JADE
        }.to raise_error(/`UserId` is a type alias, so `\(\.\.\)` has nothing to expose/)
      end
    end

    describe 'implements on an imported alias is rejected' do
      before do
        test_compiler.write(<<~JADE)
          module SharedIds exposing (UserId)

          type alias UserId = Int
        JADE
      end

      let(:source) do
        <<~JADE
          module UsesIds exposing (Show, show)

          import SharedIds exposing (UserId)


          interface Show(a) with
            show : a -> String
          end


          implements Show(UserId) with
            show: id_show
          end


          def id_show(n: UserId) -> String
            "id"
          end
        JADE
      end

      it 'reports rather than reaching codegen' do
        expect { test_compiler.require(source) }
          .to raise_error(/Cannot implement `UsesIds.Show` for type alias `SharedIds.UserId`/)
      end
    end

    describe 'aliases in port signatures' do
      it 'accepts an alias over a Task' do
        expect {
          test_compiler.require(<<~JADE)
            module PortAlias exposing (go)

            type alias Job = Task(Int, Never)


            uses Jade::TestBetterDate with
              internal_today : Job
            end


            def go -> Job
              internal_today()
            end
          JADE
        }.not_to raise_error
      end

      it 'still sees a nested Task hidden behind one' do
        expect {
          test_compiler.require(<<~JADE)
            module PortNested exposing (go)

            type alias Inner = Task(Int, Never)


            type alias Outer = Task(Inner, Never)


            uses Jade::TestBetterDate with
              internal_today : Outer
            end


            def go -> Outer
              internal_today()
            end
          JADE
        }.to raise_error(/tasks must not return tasks/)
      end

      it 'still sees one passed as an alias argument' do
        expect {
          test_compiler.require(<<~JADE)
            module PortParamNested exposing (go)

            type alias Job(a) = Task(a, Never)


            uses Jade::TestBetterDate with
              internal_today : Job(Task(Int, Never))
            end


            def go -> Job(Task(Int, Never))
              internal_today()
            end
          JADE
        }.to raise_error(/tasks must not return tasks/)
      end
    end

    # An alias is its body here as everywhere else, so it cannot stand
    # between a type and itself and hide that there is no way to build one.
    describe 'an alias does not hide a type with no base case' do
      def compiling(body)
        -> {
          test_compiler.require(<<~JADE)
            module AliasBase exposing (go)

            #{body}


            def go -> Int
              1
            end
          JADE
        }
      end

      it 'sees through an alias standing between a struct and itself' do
        expect(&compiling("type alias A = S\n\n\nstruct S = { a: A }"))
          .to raise_error(/`S` can never be built/)
      end

      it 'sees through an alias standing between a union and itself' do
        expect(&compiling("type alias A = T\n\n\ntype T = Mk(A)"))
          .to raise_error(/`T` can never be built/)
      end

      it 'substitutes the arguments of a parameterised alias first' do
        expect(&compiling("type alias Pair(a) = (a, a)\n\n\nstruct S = { p: Pair(S) }"))
          .to raise_error(/`S` can never be built/)
      end

      it 'leaves an alias that gives the type a way out alone' do
        expect(&compiling("type alias A = Maybe(S)\n\n\nstruct S = { a: A }"))
          .not_to raise_error
      end

      it 'leaves a parameterised alias over something else alone' do
        expect(&compiling("type alias Pair(a) = (a, a)\n\n\nstruct S = { p: Pair(Int) }"))
          .not_to raise_error
      end
    end

    describe 'too few arguments for a parameterised alias' do
      let(:source) do
        <<~JADE
          module TooFew exposing (go)

          type alias Pair(a, b) = (a, b)


          def go(p: Pair(Int)) -> Int
            1
          end
        JADE
      end

      it 'counts them' do
        expect { test_compiler.require(source) }
          .to raise_error(/`Pair` type needs 2 arguments but got 1/)
      end
    end

    describe 'the alias name survives into diagnostics' do
      def mismatch_for(declaration, signature)
        test_compiler.require(<<~JADE)
          module Named#{signature.gsub(/\W/, '')} exposing (go)

          #{declaration}


          def go(x: #{signature}) -> #{signature}
            "nope"
          end
        JADE
        nil
      rescue CompilationError => e
        e.message
      end

      it 'names the alias and spells out its body' do
        expect(mismatch_for('type alias UserId = Int', 'UserId'))
          .to include('should be UserId (= Int)')
      end

      it 'keeps the short name in a nested position' do
        expect(mismatch_for('type alias UserId = Int', 'List(UserId)'))
          .to include('should be List(UserId)')
      end

      it 'carries the arguments of a parameterised alias' do
        expect(mismatch_for('type alias Pair(a) = (a, a)', 'Pair(Int)'))
          .to include('should be Pair(Int) (= (Int, Int))')
      end

      it 'leaves a type nobody aliased alone' do
        expect(mismatch_for('type alias Unused = Int', 'Int'))
          .to include('should be Int')
      end
    end

    # An alias over a private struct hands out a value you can hold but
    # cannot read or build — the opaque-type idiom, and worth pinning so a
    # later change to expansion does not quietly open it.
    describe 'an alias does not widen what its body exposes' do
      before do
        test_compiler.write(<<~JADE)
          module Opaque exposing (Handle, mk)

          struct Inner = {
            a: Int,
            b: Int
          }


          type alias Handle = Inner


          def mk -> Handle
            Inner(1, 2)
          end
        JADE
      end

      it 'refuses to read a field through the alias' do
        expect {
          test_compiler.require(<<~JADE)
            module ReadsHandle exposing (go)

            import Opaque exposing (Handle, mk)


            def go -> Int
              mk.a
            end
          JADE
        }.to raise_error(/record access/)
      end

      it 'refuses to construct through the alias' do
        expect {
          test_compiler.require(<<~JADE)
            module BuildsHandle exposing (go)

            import Opaque exposing (Handle)


            def go -> Handle
              Handle(1, 2)
            end
          JADE
        }.to raise_error(/cannot find a `Handle` constructor/)
      end
    end

    describe '`alias` is only a keyword after `type`' do
      before do
        test_compiler.require(source)
      end

      let(:source) do
        <<~JADE
          module Contextual exposing (alias_of, mk)

          type alias Named = { alias: String }


          def mk(s: String) -> Named
            { alias: s }
          end


          def alias_of(n: Named) -> String
            n.alias
          end
        JADE
      end

      it 'stays usable as a field name' do
        expect(Contextual.mk('hi')).to eql({ 'alias' => 'hi' })
        expect(Contextual.alias_of({ alias: 'hi' })).to eql 'hi'
      end
    end
  end
end
