require 'spec_helper'

module Jade
  describe 'ejecting a project' do
    GREETER = <<~JADE
      module Greeter exposing (greet)

      def greet(name: String) -> String
        "hello " ++ name
      end
    JADE

    COUNTER = <<~JADE
      module Counter exposing (total)

      def total -> Int
        List.sum([1, 2, 3])
      end
    JADE

    include_context 'with an ejected project', [], 'greeter' => GREETER, 'counter' => COUNTER

    it 'runs without the gem' do
      expect(ejected.run('greeter', 'Greeter.greet("world")')).to eq 'hello world'
    end

    it 'carries the intrinsics the code calls' do
      expect(ejected.run('counter', 'Counter.total')).to eq '6'
    end

    it 'takes every module, not only the ones something imports' do
      expect(ejected.files.map { File.basename(it) }).to include('greeter.rb', 'counter.rb')
    end
  end
end
