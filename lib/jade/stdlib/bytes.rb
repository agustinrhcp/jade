require 'jade/stdlib/intrinsics'

module Jade
  module Stdlib
    module Bytes
      extend Intrinsics

      import Basics
      import Maybe
      import List

      union :Bytes

      union :Endianness
      variant :LE, of: :Endianness
      variant :BE, of: :Endianness

      native_type :Bytes, Jade::Bytes::Bytes

      implementation('Eq',         'Bytes', '(==)' => 'bytes_eq')
      implementation('Appendable', 'Bytes', '(++)' => 'bytes_append')

      function(
        :empty,
        {},
        'Bytes',
      ) { Jade::Bytes::Bytes[::String.new(encoding: Encoding::BINARY)] }

      function(
        :width,
        { bytes: 'Bytes' },
        'Int',
      ) { it.bin.bytesize }

      function(
        :from_list,
        { ints: 'List(Int)' },
        'Maybe(Bytes)',
      ) do |ints|
        if ints.all? { it.is_a?(Integer) && it.between?(0, 255) }
          Jade::Maybe::Just[Jade::Bytes::Bytes[ints.pack('C*')]]
        else
          Jade::Maybe::Nothing[]
        end
      end

      function(
        :to_list,
        { bytes: 'Bytes' },
        'List(Int)',
      ) { it.bin.bytes }

      function(
        :from_string,
        { s: 'String' },
        'Bytes',
      ) { Jade::Bytes::Bytes[it.b] }

      function(
        :to_string,
        { bytes: 'Bytes' },
        'Maybe(String)',
      ) do |b|
        b.bin
          .dup
          .force_encoding(Encoding::UTF_8)
          .then { it.valid_encoding? ? Jade::Maybe::Just[it] : Jade::Maybe::Nothing[] }
      end

      default_importing('Bytes')

      function(
        'bytes_eq',
        { a: 'Bytes', b: 'Bytes' },
        'Bool',
      ) { |a, b| a.bin == b.bin }

      function(
        'bytes_append',
        { a: 'Bytes', b: 'Bytes' },
        'Bytes',
      ) { |a, b| Jade::Bytes::Bytes[a.bin + b.bin] }
    end
  end
end
