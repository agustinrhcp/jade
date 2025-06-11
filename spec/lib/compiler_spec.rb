require 'spec_helper'

require 'compiler'

describe Compiler do
  subject { described_class.compile(source_code) }

  xcontext 'a function definition' do
    let(:source_code) do
      <<~JADE
        def add(a: Int, b: Int) -> Int
          a + b
        end
      JADE
    end

    it { is_expected.to eql "def add(a, b)\n  a + b\nend" }
  end

  xcontext 'a type definition' do
    let(:source_code) do
      <<~JADE
        type User = { name: String, age: Int }
      JADE
    end

    it { is_expected.to eql "User = Data.define(:name, :age)" }
  end

  context 'a module definition' do
    let(:source_code) do
      <<~JADE
        module User exposing (User, say_hi)
          type User = { name: String, age: Int }

          def say_hi(user: User) -> String
            "Hello"
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
  end
end
