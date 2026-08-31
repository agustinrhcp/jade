require 'spec_helper'

require 'jade'
require 'jade/module_loader'

module Jade
  # Ruby rejects its keywords as locals and parameters but accepts them as
  # method names and Data members, so only bindings are rewritten — a name
  # crossing to Ruby keeps the spelling it was written with.
  describe 'Jade names that are Ruby keywords' do
    include_context 'with test compiler'

    describe 'a parameter and a local' do
      before { test_compiler.require(source) }

      let(:source) do
        <<~JADE
          module KwParam exposing (go)

          def go(begin: Int) -> Int
            next = begin + 1
            next * 2
          end
        JADE
      end

      it 'compiles and runs' do
        expect(KwParam.go(1)).to eql 4
      end
    end

    describe 'a lambda parameter' do
      before { test_compiler.require(source) }

      let(:source) do
        <<~JADE
          module KwLambda exposing (go)

          def go(xs: List(Int)) -> List(Int)
            List.map(xs, (next) -> { next * 2 })
          end
        JADE
      end

      it 'binds the block parameter and its uses to the same name' do
        expect(KwLambda.go([1, 2])).to eql [2, 4]
      end
    end

    describe 'a constructor pattern binding' do
      before { test_compiler.require(source) }

      let(:source) do
        <<~JADE
          module KwCase exposing (go)

          def go(m: Maybe(Int)) -> Int
            case m
            in Just(self) then self
            in Nothing then 0
            end
          end
        JADE
      end

      it 'compiles and runs' do
        expect(KwCase.go(7)).to eql 7
        expect(KwCase.go(nil)).to eql 0
      end
    end

    describe 'a list pattern folded into reduce' do
      before { test_compiler.require(source) }

      let(:source) do
        <<~JADE
          module KwList exposing (go)

          def go(xs: List(Int)) -> Int
            case xs
            in [] then 0
            in [begin | while] then begin + go(while)
            end
          end
        JADE
      end

      it 'names the fold block parameter the same way its body does' do
        expect(KwList.go([5, 6, 7])).to eql 18
      end
    end

    describe 'a record pattern binding' do
      before { test_compiler.require(source) }

      let(:source) do
        <<~JADE
          module KwRecord exposing (go)

          struct Row = {
            name: String,
            size: Int
          }


          def go(r: Row) -> Int
            case r
            in { name: alias, size: retry } then String.length(alias) + retry
            end
          end
        JADE
      end

      it 'compiles and runs' do
        expect(KwRecord.go(KwRecord::Row.new(name: 'abc', size: 3))).to eql 6
      end
    end

    describe 'a tail-recursive parameter rebound each pass' do
      before { test_compiler.require(source) }

      let(:source) do
        <<~JADE
          module KwTail exposing (go)

          def go(n: Int, return: Int) -> Int
            n <= 0 ? return : go(n - 1, return + n)
          end
        JADE
      end

      it 'compiles and runs' do
        expect(KwTail.go(4, 0)).to eql 10
      end
    end

    describe 'a name that already ends in an underscore' do
      before { test_compiler.require(source) }

      let(:source) do
        <<~JADE
          module KwShadow exposing (go)

          def go(begin: Int, begin_: Int) -> Int
            begin * begin_
          end
        JADE
      end

      it 'stays distinct from the keyword it would collide with' do
        expect(KwShadow.go(3, 5)).to eql 15
      end
    end

    describe 'a function whose own name is a Ruby keyword' do
      before { test_compiler.require(source) }

      let(:source) do
        <<~JADE
          module KwFunction exposing (next)

          def next(n: Int) -> Int
            n + 1
          end
        JADE
      end

      it 'keeps the spelling on the Ruby side' do
        expect(KwFunction.next(1)).to eql 2
      end
    end

    describe 'a struct field whose name is a Ruby keyword' do
      before { test_compiler.require(source) }

      let(:source) do
        <<~JADE
          module KwField exposing (Row, size_of)

          struct Row = {
            class: String,
            next: Int
          }


          def size_of(r: Row) -> Int
            r.next
          end
        JADE
      end

      it 'keeps the field name, since Data accepts it' do
        expect(KwField.size_of(KwField::Row.new(class: 'c', next: 3))).to eql 3
      end
    end
  end
end
