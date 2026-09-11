require 'spec_helper'

require 'jade'
require 'jade/module_loader'

module Jade
  describe 'One name imported from two modules' do
    include_context 'with test compiler'

    before do
      %w[alpha beta].each do |name|
        test_compiler.write(<<~JADE)
          module #{name.capitalize} exposing (Tag(..), name)

          type Tag
            = Tag


          def name -> String
            "#{name}"
          end
        JADE
      end
    end

    it 'is an error where it is used' do
      source = <<~JADE
        module AmbigUse exposing (x)

        import Alpha exposing (name)
        import Beta exposing (name)


        def x -> String
          name
        end
      JADE

      expect { test_compiler.require(source) }
        .to raise_error(CompilationError, /`name` is imported from both Alpha and Beta/)
    end

    it 'is fine while nothing uses it unqualified' do
      source = <<~JADE
        module AmbigUnused exposing (x)

        import Alpha exposing (name)
        import Beta exposing (name)


        def x -> String
          Alpha.name ++ Beta.name
        end
      JADE

      test_compiler.require(source)
      expect(AmbigUnused.x).to eq 'alphabeta'
    end

    it 'yields to a definition of the same name' do
      source = <<~JADE
        module AmbigLocal exposing (name)

        import Alpha exposing (name)
        import Beta exposing (name)


        def name -> String
          "local"
        end
      JADE

      test_compiler.require(source)
      expect(AmbigLocal.name).to eq 'local'
    end

    it 'covers constructors' do
      source = <<~JADE
        module AmbigCtor exposing (x)

        import Alpha exposing (Tag(..))
        import Beta exposing (Tag(..))


        def x -> Int
          t = Tag
          1
        end
      JADE

      expect { test_compiler.require(source) }
        .to raise_error(CompilationError, /`Tag` is imported from both Alpha and Beta/)
    end

    it 'covers a type in a signature' do
      source = <<~JADE
        module AmbigType exposing (x)

        import Alpha exposing (Tag)
        import Beta exposing (Tag)


        def x(t: Tag) -> Int
          1
        end
      JADE

      expect { test_compiler.require(source) }
        .to raise_error(CompilationError, /Type `Tag` is imported from both Alpha and Beta/)
    end

    it 'lets an explicit import win over a default one' do
      test_compiler.write(<<~JADE)
        module Shadow exposing (identity)

        def identity(n: Int) -> Int
          n + 1
        end
      JADE

      source = <<~JADE
        module AmbigDefault exposing (x)

        import Shadow exposing (identity)


        def x -> Int
          identity(1)
        end
      JADE

      test_compiler.require(source)
      expect(AmbigDefault.x).to eq 2
    end
  end
end
