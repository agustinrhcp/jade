require 'spec_helper'
require 'jade'
require 'jade/module_loader'

module Jade
  describe 'dictionary passing for polymorphic functions' do
    include_context 'with test compiler'

    it 'attaches constraint when return type wraps the type variable in a struct' do
      test_compiler.require('repro', <<~JADE)
        module Repro exposing(wrapped)

        interface Encoder(a) with
          encode : a -> String
        end

        implements Encoder(Int) with
          encode : encode_int
        end

        def encode_int(n: Int) -> String
          "int"
        end

        struct Box(a) = { value: String, tag: String }

        def wrapped(value: a) -> Box(a)
          Box(encode(value), "tag")
        end
      JADE

      build_root = test_compiler.instance_variable_get(:@build_root)
      compiled = File.read(File.join(build_root, 'repro.rb'))

      expect(compiled).to include('__wrapped__impl__')
      expect(compiled).to include('__dict0__')
    end
  end
end
