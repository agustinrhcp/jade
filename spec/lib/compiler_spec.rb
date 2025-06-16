require 'spec_helper'

require 'compiler'
require 'runtime'

using Runtime

describe Compiler do
  subject(:generated_code) { described_class.compile(source_code) }

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
  end
end
