require 'spec_helper'

require 'jade'
require 'jade/module_loader'

module Jade
  describe 'Qualified access suggestions' do
    include_context 'with test compiler'

    def help_for(source, ledger: nil)
      test_compiler.require('ledger', ledger) if ledger
      test_compiler.require('probe', source)
      []
    rescue CompilationError => e
      e.diagnostics
        .items
        .flat_map(&:annotations)
        .select { it.kind == :help }
        .map(&:message)
    end

    let(:ledger) do
      <<~JADE
        module Ledger exposing (post, revert)

        def post(n: Int) -> Int
          n
        end


        def revert(n: Int) -> Int
          n
        end
      JADE
    end

    it 'points at the stdlib function that does exist' do
      help_for(<<~JADE)
        module Probe exposing (total)

        def total(xs: List(Int)) -> Int
          xs |> List.fold_left(0, (a, b) -> { a + b })
        end
      JADE
        .then { expect(it).to include(a_string_including('`List.fold`')) }
    end

    it 'suggests through the alias the module was imported under' do
      help_for(<<~JADE, ledger:)
        module Probe exposing (go)

        import Ledger as L


        def go -> Int
          L.pst(1)
        end
      JADE
        .then { expect(it).to include(a_string_including('`L.post`')) }
    end

    it 'stays quiet when nothing is close enough to mean' do
      help_for(<<~JADE)
        module Probe exposing (total)

        def total(xs: List(Int)) -> Int
          xs |> List.qqqqqqq(0)
        end
      JADE
        .then { expect(it).to be_empty }
    end
  end
end
