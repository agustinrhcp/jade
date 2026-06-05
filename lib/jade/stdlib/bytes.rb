require 'base64'
require 'jade/stdlib/intrinsics'

module Jade
  module Stdlib
    module Bytes
      extend Intrinsics

      import Basics
      import Maybe
      import List

      union :Bytes

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

      function(
        :from_hex,
        { s: 'String' },
        'Maybe(Bytes)',
      ) do |s|
        if s.length.even? && s.match?(/\A[0-9a-fA-F]*\z/)
          Jade::Maybe::Just[Jade::Bytes::Bytes[[s].pack('H*')]]
        else
          Jade::Maybe::Nothing[]
        end
      end

      function(
        :to_hex,
        { bytes: 'Bytes' },
        'String',
      ) { it.bin.unpack1('H*') }

      function(
        :to_base64_url,
        { bytes: 'Bytes' },
        'String',
      ) { ::Base64.urlsafe_encode64(it.bin, padding: false) }

      function(
        :from_base64_url,
        { s: 'String' },
        'Maybe(Bytes)',
      ) do |s|
        Jade::Maybe::Just[Jade::Bytes::Bytes[::Base64.urlsafe_decode64(s)]]
      rescue ::ArgumentError
        Jade::Maybe::Nothing[]
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
