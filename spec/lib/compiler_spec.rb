require 'spec_helper'

require 'compiler'

describe Compiler do
  subject { described_class.compile(source_code) }

  context 'a module definition' do
    let(:source_code) do
      <<~JADE
        module User exposing (User, say_hi)
          type User = { name: String, age: Int }

          def say_hi(user: User) -> String
            "Hello \#\{user.name\}"
          end
        end
      JADE
    end

    it {
      is_expected.to eql <<~RUBY
        module User
          User = Data.define(:name, :age)
          def say_hi(user)
            "Hello"
          end
        end
      RUBY
    }

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
            User = Data.define(:name, :age)
            def init(name)
              User.new(:name => name, :age => 0)
            end
          end
        RUBY
      }
    end
  end
end
