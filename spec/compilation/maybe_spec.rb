require 'spec_helper'

require 'jade'
require 'jade/module_loader'

module Jade
  describe 'requiring the generated file' do
    include_context 'with test compiler'

    let(:maybe_source) do
      <<~JADE
        module Maybe exposing (with_default)

        type Maybe = Just(a) | Nothing

        def with_default(maybe: Maybe(a), default: a) -> a
          case maybe
          of Just(something) then something
          of Nothing then default
          end
        end
      JADE
    end

    before do
      test_compiler.require('maybe', maybe_source)
    end

    it 'works' do
      expect(Maybe.with_default.call(Maybe::Just[2], 0)).to be 2
      expect(Maybe.with_default.call(Maybe::Nothing[], 0)).to be 0
    end
  end
end
