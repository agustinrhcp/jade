require 'spec_helper'

require 'jade'
require 'jade/module_loader'

module Jade
  describe 'Importing and exposing' do
    include_context 'with test compiler'

    let(:exposing_source) do
      <<~JADE
        module Exposing exposing(MyType(..), my_function)

        type MyType = MyType | SomeOtherType(String)

        def my_function(thing: MyType) -> String
          case thing
          of MyType then "My type"
          of SomeOtherType(some_other) then some_other
          end
        end
      JADE
    end

    let(:importing_source) do
      <<~JADE
        module Importing exposing(hello)

        import Exposing

        def hello() -> String
          MyType() |> Exposing.my_function
        end
      JADE
    end

    before do
      test_compiler.write('exposing', exposing_source)
    end

    it 'fails because MyType is no in scope' do
      expect { test_compiler.require('importing', importing_source) }
        .to raise_error(RuntimeError, /cannot find a `MyType` constructor/)
    end

    context 'when exposing the type' do
      let(:importing_source) do
        <<~JADE
          module Importing exposing(hello)

          import Exposing exposing(MyType)

          def hello() -> String
            MyType() |> Exposing.my_function
          end
        JADE
      end

      before do
        test_compiler.require('exposing', exposing_source)
      end

      it 'fails because MyType is no in scope' do
        expect { test_compiler.require('importing', importing_source) }
          .to raise_error(RuntimeError, /cannot find a `MyType` constructor/)
      end
    end

    context 'when exposing and expanding the type' do
      let(:importing_source) do
        <<~JADE
          module Importing exposing(hello)

          import Exposing exposing(MyType(..))

          def hello() -> String
            MyType |> Exposing.my_function
          end
        JADE
      end

      before do
        test_compiler.write('exposing', exposing_source)
      end

      it 'works because MyType is in scope' do
        expect { test_compiler.require('importing', importing_source) }
          .to_not raise_error
        expect(Importing.hello.call()).to eql 'My type'
      end
    end

    context 'when using the type constructor qualified' do
      let(:importing_source) do
        <<~JADE
          module Importing exposing(hello)

          import Exposing

          def hello() -> String
            Exposing.MyType |> Exposing.my_function
          end
        JADE
      end

      before do
        test_compiler.require('exposing', exposing_source)
      end

      it 'it works because Exposing exposes it' do
        expect { test_compiler.require('importing', importing_source) }
          .to_not raise_error
        expect(Importing.hello.call()).to eql 'My type'
      end

      context 'but when exposing doesnt expose the constructor' do
        let(:exposing_source) do
          <<~JADE
            module Exposing exposing(MyType, my_function)

            type MyType = MyType | SomeOtherType(String)

            def my_function(thing: MyType) -> String
              case thing
              of MyType then "My type"
              of SomeOtherType(some_other) then some_other
              end
            end
          JADE
        end

        it 'fails becausse the constructor is private' do
          expect { test_compiler.require('importing', importing_source) }
            .to raise_error(RuntimeError, /cannot find a `Exposing.MyType` variable/)
        end
      end
    end

    context 'when using the type in a signature' do
      let(:importing_source) do
        <<~JADE
          module Importing exposing(hello)

          import Exposing

          def hello(exposing_type: Exposing.MyType) -> String
            exposing_type |> Exposing.my_function
          end
        JADE
      end

      before do
        test_compiler.write('exposing', exposing_source)
      end

      it 'works' do
        expect { test_compiler.require('importing', importing_source) }
          .to_not raise_error
        expect(Importing.hello.call(Exposing::MyType[])).to eql 'My type'
      end
    end

    context 'when trying to expand private type' do
      let(:exposing_source) do
        <<~JADE
          module Exposing exposing(MyType, my_function)

          type MyType = MyType | SomeOtherType(String)

          def my_function(thing: MyType) -> String
            case thing
            of MyType then "My type"
            of SomeOtherType(some_other) then some_other
            end
          end
        JADE
      end

      let(:importing_source) do
        <<~JADE
          module Importing exposing(hello)

          import Exposing exposing (MyType(..))

          def hello() -> String
            MyType() |> Exposing.my_function
          end
        JADE
      end

      it 'fails because MyType constructors are private' do
        expect { test_compiler.require('importing', importing_source) }
          .to raise_error(RuntimeError, /Exposing's `MyType` type does not allow `\(\.\.\)`/)
      end
    end

    context 'when trying to expose a missing symbol' do
      let(:exposing_source) do
        <<~JADE
          module Exposing exposing(MyType(..), my_function)

          type MyType = MyType | SomeOtherType(String)

          def my_function(thing: MyType) -> String
            case thing
            of MyType then "My type"
            of SomeOtherType(some_other) then some_other
            end
          end
        JADE
      end

      let(:importing_source) do
        <<~JADE
          module Importing exposing(hello)

          import Exposing exposing (MyType(..), wacamole)

          def hello() -> String
            MyType() |> Exposing.my_function
          end
        JADE
      end

      it 'fails because MyType constructors are private' do
        expect { test_compiler.require('importing', importing_source) }
          .to raise_error(RuntimeError, /The `Exposing` module does not expose `wacamole`/)
      end
    end

    context 'when using a polypmorphic exposed functoin' do
      let(:exposing_source) do
        <<~JADE
          module Exposing exposing(id)

          def id(thing: a) -> a
            thing
          end
        JADE
      end

      let(:importing_source) do
        <<~JADE
          module Importing exposing(hello)

          import Exposing

          def hello() -> Int
            int = Exposing.id(12)
            string = Exposing.id("12")
            int_from_string = string |> String.to_int |> Maybe.with_default(0)
            int + int_from_string
          end
        JADE
      end

      it 'fails because MyType constructors are private' do
        expect { test_compiler.require('importing', importing_source) }
          .to_not raise_error
        expect(Importing.hello.call()).to eql 24
      end
    end
  end
end
