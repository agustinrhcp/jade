require 'spec_helper'

require 'jade/symbol'
require 'jade/frontend'
require 'jade/parsing'
require 'jade/lexer'
require 'jade/ast'

module Jade
  describe Frontend::UsageAnalysis do
    let(:source) { Source.new(uri: 'test', text:) }

    let(:run) do
      Lexer
        .tokenize(source)
        .then { Parsing.parse(it, source:) }
        .and_then do |(ast, _)|
          registry, current_entry = Frontend.entry_with_basics(ast)
          Frontend
            .run_entry(current_entry, registry)
            .map { [it, registry.update_module(it)] }
        end
    end

    let(:entry) { run => Ok([entry, _]); entry }
    subject(:index) { entry.usage_index }

    describe 'a function called once' do
      let(:text) do
        <<~JADE
          module M exposing (go)

          def go(n: Int) -> Int
            helper(n)
          end


          def helper(x: Int) -> Int
            x + 1
          end
        JADE
      end

      let(:helper_sym) { entry.lookup_value('helper').to_ref }

      it 'records a :called reference' do
        expect(index.for(helper_sym).map(&:kind)).to eq [:called]
      end

      it 'reports passed_as_value? false' do
        expect(index.passed_as_value?(helper_sym)).to eq false
      end

      it 'reports ever_referenced? true' do
        expect(index.ever_referenced?(helper_sym)).to eq true
      end
    end

    describe 'a function passed as a value' do
      let(:text) do
        <<~JADE
          module M exposing (go)

          def go -> List(Int)
            List.map([1, 2, 3], double)
          end


          def double(x: Int) -> Int
            x + x
          end
        JADE
      end

      let(:double_sym) { entry.lookup_value('double').to_ref }

      it 'records :as_value' do
        expect(index.for(double_sym).map(&:kind)).to eq [:as_value]
      end

      it 'reports passed_as_value? true' do
        expect(index.passed_as_value?(double_sym)).to eq true
      end
    end

    describe 'a never-referenced private function' do
      let(:text) do
        <<~JADE
          module M exposing (go)

          def go -> Int
            1
          end


          def unused(x: Int) -> Int
            x + 1
          end
        JADE
      end

      let(:unused_sym) { entry.lookup_value('unused').to_ref }

      it 'reports ever_referenced? false' do
        expect(index.ever_referenced?(unused_sym)).to eq false
      end
    end

    describe 'a constructor used in pattern' do
      let(:text) do
        <<~JADE
          module M exposing (go)

          def go(m: Maybe(Int)) -> Int
            case m
            in Just(x) then x
            in Nothing then 0
            end
          end
        JADE
      end

      it 'records :pattern_match for Just' do
        kinds = index
          .references
          .values
          .flatten
          .select { it.symbol_key == ['Maybe', 'Just'] }
          .map(&:kind)

        expect(kinds).to include(:pattern_match)
      end
    end

    describe 'a local variable referenced twice' do
      let(:text) do
        <<~JADE
          module M exposing (go)

          def go(x: Int) -> Int
            x + x
          end
        JADE
      end

      it 'collapses both refs under one :local key' do
        local_keys = index
          .references
          .keys
          .select { it.first == :local }

        expect(local_keys.size).to eq 1
        expect(index.references[local_keys.first].size).to eq 2
      end
    end

    describe 'owner' do
      let(:owners_of) do
        ->(key) do
          index
            .references
            .values
            .flatten
            .select { it.symbol_key == key }
            .map(&:owner)
        end
      end

      describe 'a call inside a declaration' do
        let(:text) do
          <<~JADE
            module M exposing (go)

            def go(n: Int) -> Int
              helper(n)
            end


            def helper(x: Int) -> Int
              x + 1
            end
          JADE
        end

        it 'is the enclosing declaration' do
          expect(owners_of.(['M', 'helper'])).to eq [['M', 'go']]
        end

        it 'is in the same namespace as the key it owns' do
          expect(index.references).to have_key(owners_of.(['M', 'helper']).first)
        end
      end

      describe 'a call inside a lambda' do
        let(:text) do
          <<~JADE
            module M exposing (go)

            def go -> List(Int)
              List.map([1, 2, 3], (n) -> { double(n) })
            end


            def double(x: Int) -> Int
              x + x
            end
          JADE
        end

        it 'is the declaration enclosing the lambda' do
          expect(owners_of.(['M', 'double'])).to eq [['M', 'go']]
        end
      end

      # The reason `owner` exists: `<-` desugars into `Basics.and_then`
      # with no range, so range-bucketing against declaration spans
      # cannot attribute it.
      describe 'a desugared bind' do
        let(:text) do
          <<~JADE
            module M exposing (go)

            def go -> Task(Int, Never)
              n <- Task.succeed(1)

              Task.succeed(n + 1)
            end
          JADE
        end

        subject(:binds) do
          index
            .references
            .values
            .flatten
            .select { it.symbol_key == ['Basics', 'and_then'] }
        end

        it 'carries no range' do
          expect(binds.map(&:range)).to eq [nil]
        end

        it 'is owned anyway' do
          expect(binds.map(&:owner)).to eq [['M', 'go']]
        end
      end

      describe 'an implementation function' do
        let(:text) do
          <<~JADE
            module M exposing (Pepe)

            type Pepe = Pepe(Int)


            implements Eq(Pepe) with
              (==): (one, other) -> { same?(one, other) }
            end


            def same?(one: Pepe, other: Pepe) -> Bool
              True
            end
          JADE
        end

        it 'is the implementation, which has no enclosing declaration' do
          expect(owners_of.(['M', 'same?']))
            .to eq [[:impl, *entry.implementations.keys.first]]
        end
      end

      describe 'the exposing list' do
        let(:text) do
          <<~JADE
            module M exposing (go)

            def go -> Int
              1
            end
          JADE
        end

        it 'has no owner, being module level' do
          expect(index.for(entry.lookup_value('go').to_ref).map { [it.kind, it.owner] })
            .to include([:exposed, nil])
        end
      end
    end
  end
end
