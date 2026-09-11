require 'spec_helper'
require 'securerandom'
require 'tmpdir'

require 'jade'
require 'jade/module_loader'

module Jade
  describe 'REPL cells' do
    let(:root) { Dir.mktmpdir('jade-cells') }
    let(:build) { File.join(root, 'build') }
    let(:space) { "cells_#{SecureRandom.alphanumeric(8).downcase}" }

    after { FileUtils.rm_rf(root) }

    def uri(n)
      "#{space}/c#{n}.jd"
    end

    def mod(n)
      Source.new(uri: uri(n), text: '').to_module_name
    end

    def internal(n)
      Object.const_get(mod(n).gsub('.', '::'))::Internal
    end

    def load(*sources, session: true)
      sources
        .each_with_index
        .to_h { |text, i| [uri(i + 1), text] }
        .then do |overlays|
          ModuleLoader.load(
            root,
            uri(sources.size),
            overlays:,
            cells: session ? (1..sources.size).map { mod(it) }.to_set : ::Set[],
          )
        end
    end

    def evaluate(*sources, name)
      load(*sources).then { ModuleLoader.emit(it, path: build) }
      require File.join(build, uri(sources.size).sub(/\.jd\z/, '.rb'))

      internal(sources.size).public_send(name)
    end

    it 'binds a value at the top level, its type inferred' do
      expect(evaluate(<<~JADE, :limit)).to eq 3
        module #{mod(1)} exposing (limit)

        limit = 1 + 2
      JADE
    end

    it 'hands the value to a later cell' do
      first = <<~JADE
        module #{mod(1)} exposing (limit)

        limit = 3
      JADE

      second = <<~JADE
        module #{mod(2)} exposing (doubled)

        import #{mod(1)} exposing (limit)

        doubled = limit * 2
      JADE

      expect(evaluate(first, second, :doubled)).to eq 6
    end

    it 'evaluates a binding once' do
      evaluate(<<~JADE, :xs)
        module #{mod(1)} exposing (xs)

        xs = [1, 2]
      JADE

      expect(internal(1).xs).to equal(internal(1).xs)
    end

    it 'generalises a binding' do
      first = <<~JADE
        module #{mod(1)} exposing (none)

        none = []
      JADE

      second = <<~JADE
        module #{mod(2)} exposing (both)

        import #{mod(1)} exposing (none)

        both = (none ++ [1], none ++ ["a"])
      JADE

      expect(evaluate(first, second, :both)).to have_attributes(_1: [1], _2: ['a'])
    end

    it 'lets a function read a binding' do
      expect(evaluate(<<~JADE, :tripled)).to eq 6
        module #{mod(1)} exposing (tripled)

        rate = 3


        def triple(n: Int) -> Int
          n * rate
        end

        tripled = triple(2)
      JADE
    end

    it 'keeps a binding that needs a dictionary a function of it' do
      first = <<~JADE
        module #{mod(1)} exposing (same)

        same = (a, b) -> { a == b }
      JADE

      second = <<~JADE
        module #{mod(2)} exposing (answer)

        import #{mod(1)} exposing (same)

        answer = same(1, 1)
      JADE

      expect(evaluate(first, second, :answer)).to be true
    end

    it 'still rejects a binding outside a session' do
      source = <<~JADE
        module #{mod(1)} exposing (limit)

        x = 2


        def limit -> Int
          3
        end
      JADE

      expect { load(source, session: false) }
        .to raise_error(CompilationError, /Only declarations/)
    end

    describe 'implementations' do
      let(:point) do
        <<~JADE
          module #{mod(1)} exposing (Point(..))

          struct Point = {
            x: Int,
            y: Int
          }
        JADE
      end

      let(:shows_point) do
        <<~JADE
          module #{mod(2)} exposing (shown)

          import Show exposing (Show)
          import #{mod(1)} exposing (Point(..))


          implements Show(Point) with
            show: (p) -> { String.from_int(p.x) }
          end

          shown = Show.show(Point(1, 2))
        JADE
      end

      it 'implements an interface for a type from an earlier cell' do
        expect(evaluate(point, shows_point, :shown)).to eq '1'
      end

      it 'carries the implementation into a later cell' do
        third = <<~JADE
          module #{mod(3)} exposing (again)

          import Show
          import #{mod(1)} exposing (Point(..))
          import #{mod(2)}

          again = Show.show(Point(7, 0))
        JADE

        expect(evaluate(point, shows_point, third, :again)).to eq '7'
      end

      it 'rejects a second implementation in a later cell' do
        third = <<~JADE
          module #{mod(3)} exposing (again)

          import Show exposing (Show)
          import #{mod(1)} exposing (Point(..))
          import #{mod(2)}


          implements Show(Point) with
            show: (p) -> { "other" }
          end

          again = 1
        JADE

        expect { load(point, shows_point, third) }
          .to raise_error(CompilationError, /already implemented for #{mod(1)}\.Point, in #{mod(2)}/)
      end
    end
  end
end
