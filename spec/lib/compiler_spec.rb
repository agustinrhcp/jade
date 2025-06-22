require 'spec_helper'

require 'compiler'
require 'runtime'

using Runtime

describe Compiler do
  subject(:generated_code) { described_class.compile(source_code) }

  context 'a simple function definition within a module' do
    let(:source_code) do
      <<~JADE
        module Math exposing (double)
          def double(n: Int) -> Int
            let two = 2
            n * two
          end
        end
      JADE
    end

    it {
      is_expected.to eql <<~RUBY
        module Math
          extend self
          def double(n)
            two = 2
            n * two
          end
        end
      RUBY
    }
  end

  context 'a module definition' do
    let(:source_code) do
      <<~JADE
        module User exposing (User, say_hi)
          type User = { name: String, age: Int }

          def say_hi(user: User) -> String
            "Hello " ++ user.name
          end
        end
      JADE
    end

    it {
      is_expected.to eql <<~RUBY
        module User
          extend self
          User = Data.define(:name, :age)
          def say_hi(user)
            "Hello " ++ user.send(:name)
          end
        end
      RUBY
    }

    describe 'evaling' do
      subject do
        Module.new
          .tap { it.module_eval(generated_code) }
          .then { it::User }
      end

      it 'works' do
        pepe = subject::User.new("Pepe", 0)
        expect(subject.say_hi(pepe)).to eql 'Hello Pepe'
      end
    end

    context 'with record instantiation' do
      let(:source_code) do
        <<~JADE
          module User exposing (User, init)
            type User = { name: String, age: Int }

            def init(name: String) -> User
              User(name: name, age: 0)
            end
          end
        JADE
      end

      it {
        is_expected.to eql <<~RUBY
          module User
            extend self
            User = Data.define(:name, :age)
            def init(name)
              User.new(:name => name, :age => 0)
            end
          end
        RUBY
      }

      describe 'evaling' do
        subject do
          Module.new
            .tap { it.module_eval(generated_code) }
            .then { it::User }
        end

        it 'works' do
          pepe = subject::init("Pepe")
          expect(pepe.name).to eql 'Pepe'
        end
      end
    end

    context 'with union type' do
      let(:source_code) do
        <<~JADE
          module Result exposing (Result)
            type Result = Ok(String) | Err
          end
        JADE
      end

      it {
        is_expected.to eql <<~RUBY
          module Result
            extend self
            Result_Ok = Data.define(:tuple)
            Result_Err = Data.define
          end
        RUBY
      }
    end

    context 'with generic union type' do
      let(:source_code) do
        <<~JADE
          module Result exposing (Result)
            type Result ok err = Ok(ok) | Err(err)
          end
        JADE
      end

      it {
        is_expected.to eql <<~RUBY
          module Result
            extend self
            def Result(ok_type, err_type)
              Module.new do
                const_set :Result_Ok, Data.define(:tuple)
                const_set :Result_Err, Data.define(:tuple)
                extend self
              end
            end
          end
        RUBY
      }

      describe 'evaling' do
        subject do
          Module.new
            .tap { it.module_eval(generated_code) }
            .then { it::Result }
        end

        it 'works with different types' do
          string_int_result = subject.Result(String, Integer)
          ok_value = string_int_result::Result_Ok.new("success")
          err_value = string_int_result::Result_Err.new(404)
          
          expect(ok_value.tuple).to eql "success"
          expect(err_value.tuple).to eql 404
        end
      end
    end

    context 'with generic record type' do
      let(:source_code) do
        <<~JADE
          module User exposing (User)
            type User a = { name: String, random: a }
        end
        JADE
      end

      it {
        is_expected.to eql <<~RUBY
          module User
            extend self
            def User(a_type)
              Data.define(:name, :random)
            end
          end
        RUBY
      }

      describe 'evaling' do
        subject do
          Module.new
            .tap { it.module_eval(generated_code) }
            .then { it::User }
        end

        it 'works with different generic types' do
          int_user_class = subject.User(Integer)
          string_user_class = subject.User(String)
          
          int_user = int_user_class.new("John", 42)
          string_user = string_user_class.new("Jane", "extra_data")
          
          expect(int_user.name).to eql "John"
          expect(int_user.random).to eql 42
          expect(string_user.name).to eql "Jane"
          expect(string_user.random).to eql "extra_data"
        end
      end
    end

    context 'with generic record instantiation' do
      let(:source_code) do
        <<~JADE
          module Container exposing (Container, create)
            type Container a = { value: a, label: String }

            def create(val: a, name: String) -> Container a
              Container(value: val, label: name)
            end
          end
        JADE
      end

      it {
        is_expected.to eql <<~RUBY
          module Container
            extend self
            def Container(a_type)
              Data.define(:value, :label)
            end
            def create(val, name)
              Container(Object).new(:value => val, :label => name)
            end
          end
        RUBY
      }

      describe 'evaling' do
        subject do
          Module.new
            .tap { it.module_eval(generated_code) }
            .then { it::Container }
        end

        it 'works with record instantiation' do
          int_container = subject.create(42, "number")
          string_container = subject.create("hello", "greeting")
          
          expect(int_container.value).to eql 42
          expect(int_container.label).to eql "number"
          expect(string_container.value).to eql "hello"
          expect(string_container.label).to eql "greeting"
        end
      end
    end
  end
end
