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

      function(:empty, {}, 'Bytes')
      function(:width, { bytes: 'Bytes' }, 'Int')

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

      function(:to_list, { bytes: 'Bytes' }, 'List(Int)')
      function(:from_string, { s: 'String' }, 'Bytes')
      function(:to_string, { bytes: 'Bytes' }, 'Maybe(String)')

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

      function(:to_hex, { bytes: 'Bytes' }, 'String')
      function(:to_base64_url, { bytes: 'Bytes' }, 'String')

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

      function('bytes_eq', { a: 'Bytes', b: 'Bytes' }, 'Bool')
      function('bytes_append', { a: 'Bytes', b: 'Bytes' }, 'Bytes')
    end
  end
end
