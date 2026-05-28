require 'spec_helper'

require 'jade'
require 'jade/module_loader'

module Jade
  describe 'cross-module polymorphic helper' do
    include_context 'with test compiler'

    let(:loader_source) do
      <<~JADE
        module Loader exposing (WithAssoc(..), with_assoc)

        struct WithAssoc(p, a) = {
          primary: p,
          assocs: List(a)
        }


        def with_assoc(
          primaries: List(p),
          primary_key: p -> k,
          fetch_assocs: List(k) -> Task(List(a), e),
          assoc_key: a -> k,
        ) -> Task(List(WithAssoc(p, a)), e)
          ids = List.map(primaries, primary_key)
          assocs <- fetch_assocs(ids)
          Task.succeed(
            List.map(
              primaries,
              (p) -> { WithAssoc(p, List.filter(assocs, (a) -> { assoc_key(a) == primary_key(p) })) },
            ),
          )
        end
      JADE
    end

    let(:app_source) do
      <<~JADE
        module App exposing (test_call)

        import Loader exposing (WithAssoc, with_assoc)


        struct Person = { id: Int }


        struct Pet = { owner_id: Int }


        def fetch(ids: List(Int)) -> Task(List(Pet), String)
          Task.succeed([])
        end


        def test_call(
          people: List(Person),
        ) -> Task(List(WithAssoc(Person, Pet)), String)
          with_assoc(people, (p) -> {
            p.id
          }, fetch, (pt) -> {
            pt.owner_id
          })
        end
      JADE
    end

    it 'keeps helper type vars distinct from arg type vars' do
      test_compiler.require('loader', loader_source)
      expect { test_compiler.require('app', app_source) }.not_to raise_error
    end
  end
end
