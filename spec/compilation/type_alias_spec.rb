require 'spec_helper'

require 'jade'
require 'jade/module_loader'

module Jade
  describe 'Type alias' do
    include_context 'with test compiler'

    around do |ex|
      ENV['JADE_SKIP_FORMAT_CHECK'] = '1'
      ex.run
    ensure
      ENV.delete('JADE_SKIP_FORMAT_CHECK')
    end

    describe 'aliasing a primitive' do
      before do
        test_compiler.require('user_id', source)
      end

      let(:source) do
        <<~JADE
          module UserId exposing (zero, inc)

          type alias UserId = Int


          def zero -> UserId
            0


          def inc(id: UserId) -> UserId
            id + 1
        JADE
      end

      it 'compiles and treats the alias like the underlying type' do
        expect(UserId.zero).to eql 0
        expect(UserId.inc(41)).to eql 42
      end
    end

    describe 'aliasing a tuple' do
      before do
        test_compiler.require('points', source)
      end

      let(:source) do
        <<~JADE
          module Points exposing (origin, sum_coords)

          type alias Point = (Int, Int)


          def origin -> Point
            (0, 0)


          def sum_coords(p: Point) -> Int
            Tuple.first(p) + Tuple.second(p)
        JADE
      end

      it 'compiles and the tuple alias unifies with a tuple literal' do
        expect(Points::Internal.origin).to eql Tuple::Tuple2[0, 0]
        expect(Points::Internal.sum_coords(Tuple::Tuple2[3, 4])).to eql 7
      end
    end

    describe 'aliasing an applied generic' do
      before do
        test_compiler.require('look_up', source)
      end

      let(:source) do
        <<~JADE
          module LookUp exposing (found, missing)

          type alias UserResult = Result(Int, String)


          def found -> UserResult
            Ok(42)


          def missing -> UserResult
            Err("not found")
        JADE
      end

      it 'aliases resolve through Result and constructors unify' do
        expect(LookUp::Internal.found).to be_ok(42)
        expect(LookUp::Internal.missing).to be_err("not found")
      end
    end

    describe 'parameterised alias' do
      before do
        test_compiler.require('pair_module', source)
      end

      let(:source) do
        <<~JADE
          module PairModule exposing (mk, swap)

          type alias Pair(a) = (a, a)


          def mk(x: Int, y: Int) -> Pair(Int)
            (x, y)


          def swap(p: Pair(Int)) -> Pair(Int)
            (Tuple.second(p), Tuple.first(p))
        JADE
      end

      it 'type params substitute correctly' do
        expect(PairModule::Internal.mk(1, 2)).to eql Tuple::Tuple2[1, 2]
        expect(PairModule::Internal.swap(Tuple::Tuple2[1, 2])).to eql Tuple::Tuple2[2, 1]
      end
    end

    describe 'record alias crosses the boundary via Encode' do
      before do
        test_compiler.require('users_encode', source)
      end

      let(:source) do
        <<~JADE
          module UsersEncode exposing (alice)

          type alias User = { name: String, age: Int }


          def alice -> User
            { name: "Alice", age: 30 }
        JADE
      end

      it 'auto-derives Encodable for a record alias' do
        encoded = UsersEncode.alice
        expect(encoded).to eql({ 'name' => 'Alice', 'age' => 30 })
      end
    end

    describe 'record alias crosses the boundary via Decode' do
      before do
        test_compiler.require('users_decode', source)
      end

      let(:source) do
        <<~JADE
          module UsersDecode exposing (name_of)

          type alias User = { name: String, age: Int }


          def name_of(u: User) -> String
            u.name
        JADE
      end

      it 'auto-derives Decodable for a record alias' do
        expect(UsersDecode.name_of({ 'name' => 'Bob', 'age' => 0 })).to eql 'Bob'
      end
    end

    describe 'aliasing a function type' do
      before do
        test_compiler.require('handlers', source)
      end

      let(:source) do
        <<~JADE
          module Handlers exposing (apply_int)

          type alias IntFn = Int -> Int


          def apply_int(f: IntFn, x: Int) -> Int
            f(x)
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
        JADE
      end

      it 'raises a recursive-alias error' do
        expect { test_compiler.require('bad', source) }
          .to raise_error(/recursive/i)
      end
    end

    describe 'alias is exposed and consumed across modules' do
      before do
        test_compiler.require('shared_types', shared_source)
        test_compiler.require('shared_consumer', consumer_source)
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
        JADE
      end

      it 'a cross-module alias resolves and works at the boundary' do
        expect(SharedConsumer.next_id(41)).to eql 42
      end
    end

    describe 'alias inside a struct field' do
      before do
        test_compiler.require('user_with_id', source)
      end

      let(:source) do
        <<~JADE
          module UserWithId exposing (mk, id_of)

          type alias UserId = Int

          struct UserRow = { id: UserId, name: String }


          def mk(id: UserId, name: String) -> UserRow
            UserRow(id, name)


          def id_of(row: UserRow) -> UserId
            row.id
        JADE
      end

      it 'aliases used as struct field types work transparently' do
        row = UserWithId::Internal.mk(7, 'Carol')
        expect(UserWithId::Internal.id_of(row)).to eql 7
      end
    end

    describe 'alias to alias' do
      before do
        test_compiler.require('aliases_chain', source)
      end

      let(:source) do
        <<~JADE
          module AliasesChain exposing (zero, plus_one)

          type alias A = Int

          type alias B = A


          def zero -> B
            0


          def plus_one(b: B) -> A
            b + 1
        JADE
      end

      it 'chained aliases unify all the way down' do
        expect(AliasesChain.zero).to eql 0
        expect(AliasesChain.plus_one(5)).to eql 6
      end
    end

    describe 'unbound type variable is rejected' do
      let(:source) do
        <<~JADE
          module BadAlias exposing (whatever)

          type alias Wrong = List(a)


          def whatever -> Int
            0
        JADE
      end

      it 'raises an unbound-type-variable error' do
        expect { test_compiler.require('bad_alias', source) }
          .to raise_error(/unbound/i)
      end
    end
  end
end
