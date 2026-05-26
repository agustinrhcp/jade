require 'spec_helper'

require 'jade/symbol'
require 'jade/frontend'
require 'jade/parsing'
require 'jade/lexer'
require 'jade/ast'

module Jade
  describe Frontend::UnusedAnalysis do
    let(:source) { Source.new(uri: 'test', text:) }

    let(:entry) do
      Lexer
        .tokenize(source)
        .then { Parsing.parse(it, entry: source.uri) }
        .and_then do |(ast, _)|
          registry, current_entry = Frontend.entry_with_basics(ast)
          Frontend.run_entry(current_entry, registry).map { [it, registry] }
        end
        .then { it => Ok([entry, _]); entry }
    end

    let(:warnings) do
      entry.diagnostics.items.select { it.severity == :warning }
    end

    describe 'a private unused function' do
      let(:text) do
        <<~JADE
          module M exposing (n)

          def dead(x: Int) -> Int
            x + 1

          def n() -> Int
            42
        JADE
      end

      it 'emits exactly one unused warning' do
        expect(warnings.size).to eq 1
        expect(warnings.first.message).to include('dead')
      end

      it 'points the warning at the def' do
        span = warnings.first.primary.span
        expect(text[span]).to start_with('def dead')
      end
    end

    describe 'a private used function' do
      let(:text) do
        <<~JADE
          module M exposing (n)

          def helper(x: Int) -> Int
            x + 1

          def n() -> Int
            helper(42)
        JADE
      end

      it 'emits no warning' do
        expect(warnings).to be_empty
      end
    end

    describe 'an exposed but unreferenced function' do
      let(:text) do
        <<~JADE
          module M exposing (n, also_exposed)

          def also_exposed(x: Int) -> Int
            x + 1

          def n() -> Int
            42
        JADE
      end

      it 'does not warn (external callers may consume it)' do
        expect(warnings).to be_empty
      end
    end
  end
end
