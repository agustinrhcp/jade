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
  end
end
