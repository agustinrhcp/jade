module Jade
  module Codegen
    module Inlines
      extend self

      # Ruby's native ordering on these types matches LT/EQ/GT semantics, so
      # the derived comparison ops can collapse to plain operators.
      RUBY_NATIVE_COMPARES = %w[Basics.int_compare Basics.float_compare String.str_compare].to_set.freeze
      RUBY_NATIVE_EQS = %w[Basics.int_eq Basics.float_eq Basics.bool_eq String.str_eq].to_set.freeze

      DERIVED_COMPARISONS = {
        'Basics.(<)'  => ->(a, b) { "(#{a} < #{b})" },
        'Basics.(>)'  => ->(a, b) { "(#{a} > #{b})" },
        'Basics.(<=)' => ->(a, b) { "(#{a} <= #{b})" },
        'Basics.(>=)' => ->(a, b) { "(#{a} >= #{b})" },
      }.freeze

      INLINES = {
        'Basics.identity'   => ->(a)    { a },
        'Basics.always'     => ->(x)    { "->(_) { #{x} }" },
        'Basics.int_add'    => ->(a, b) { "(#{a} + #{b})" },
        'Basics.int_sub'    => ->(a, b) { "(#{a} - #{b})" },
        'Basics.int_mul'    => ->(a, b) { "(#{a} * #{b})" },
        'Basics.int_div'    => ->(a, b) { "(#{a} / #{b})" },
        'Basics.mod'        => ->(a, b) { "(#{a} % #{b})" },
        'Basics.float_add'  => ->(a, b) { "(#{a} + #{b})" },
        'Basics.float_sub'  => ->(a, b) { "(#{a} - #{b})" },
        'Basics.float_mul'  => ->(a, b) { "(#{a} * #{b})" },
        'Basics.float_div'  => ->(a, b) { "(#{a} / #{b})" },
        'Basics.int_compare'   => ->(a, b) { "#{a}.compare(#{b})" },
        'Basics.float_compare' => ->(a, b) { "#{a}.compare(#{b})" },
        'Basics.(&&)'       => ->(a, b) { "(#{a} && #{b})" },
        'Basics.(||)'       => ->(a, b) { "(#{a} || #{b})" },
        'Basics.not'        => ->(a)    { "(!#{a})" },
        'Basics.int_eq'     => ->(a, b) { "(#{a} == #{b})" },
        'Basics.float_eq'   => ->(a, b) { "(#{a} == #{b})" },
        'Basics.bool_eq'    => ->(a, b) { "(#{a} == #{b})" },
        'Basics.to_float'   => ->(n)    { "#{n}.to_f" },
        'Basics.floor'      => ->(n)    { "#{n}.floor" },
        'Basics.ceiling'    => ->(n)    { "#{n}.ceil" },
        'Basics.round'      => ->(n)    { "#{n}.round" },
        'Basics.truncate'   => ->(n)    { "#{n}.truncate" },

        'String.str_append'  => ->(a, b)        { "(#{a} + #{b})" },
        'String.str_eq'      => ->(a, b)        { "(#{a} == #{b})" },
        'String.str_compare' => ->(a, b)        { "#{a}.compare(#{b})" },
        'String.empty?'     => ->(s)           { "#{s}.empty?" },
        'String.length'     => ->(s)           { "#{s}.length" },
        'String.reverse'    => ->(s)           { "#{s}.reverse" },
        'String.cons'       => ->(head, tail)  { "(#{head} + #{tail})" },
        'String.from_char'  => ->(c)           { c },
        'String.from_int'   => ->(n)           { "#{n}.to_s" },
        'String.to_int'     => ->(s)           { "(Jade::Maybe::Just[Integer(#{s}, 10)] rescue Jade::Maybe::Nothing[])" },
        'String.uncons'     => ->(s)           { "#{s}.then { |s| s.empty? ? Jade::Maybe::Nothing[] : Jade::Maybe::Just[Jade::Tuple::Tuple2[s[0], s[1..]]] }" },
        'String.repeat'     => ->(s, n)        { "(#{s} * #{n})" },
        'String.split'      => ->(s, by)       { "#{s}.split(#{by})" },
        'String.concat'     => ->(xs)          { "#{xs}.join" },
        'String.join'       => ->(xs, with)    { "#{xs}.join(#{with})" },
        'String.map'        => ->(s, fn)       { "#{s}.chars.map(&#{fn}).join" },
        'String.trim'       => ->(s)           { "#{s}.strip" },
        'String.trim_left'  => ->(s)           { "#{s}.lstrip" },
        'String.trim_right' => ->(s)           { "#{s}.rstrip" },
        'String.to_lower'   => ->(s)           { "#{s}.downcase" },
        'String.to_upper'   => ->(s)           { "#{s}.upcase" },
        'String.contains?'  => ->(s, sub)      { "#{s}.include?(#{sub})" },
        'String.starts_with?' => ->(s, p)      { "#{s}.start_with?(#{p})" },
        'String.ends_with?' => ->(s, p)        { "#{s}.end_with?(#{p})" },
        'String.replace'    => ->(s, t, r)     { "#{s}.gsub(#{t}, #{r})" },
        'String.slice'      => ->(s, a, b)     { "(#{s}[#{a}...#{b}] || '')" },
        'String.words'      => ->(s)           { "#{s}.split(/\\s+/).reject(&:empty?)" },
        'String.lines'      => ->(s)           { "#{s}.split(\"\\n\", -1)" },
        'String.to_list'    => ->(s)           { "#{s}.chars" },
        'String.from_list'  => ->(xs)          { "#{xs}.join" },

        'List.head'         => ->(xs)          { "#{xs}.then { |xs| xs.empty? ? Jade::Maybe::Nothing[] : Jade::Maybe::Just[xs.first] }" },
        'List.find'         => ->(xs, fn)      { "#{xs}.find(&#{fn}).then { |m| m.nil? ? Jade::Maybe::Nothing[] : Jade::Maybe::Just[m] }" },
        'List.partition'    => ->(xs, fn)      { "Jade::Tuple::Tuple2[*#{xs}.partition(&#{fn})]" },
        'List.unzip'        => ->(xs)          { "#{xs}.then { |xs| Jade::Tuple::Tuple2[xs.map(&:_1), xs.map(&:_2)] }" },
        'List.singleton'    => ->(x)           { "[#{x}]" },
        'List.repeat'       => ->(x, n)        { "([#{x}] * #{n})" },
        'List.range'        => ->(lo, hi)      { "(#{lo}..#{hi}).to_a" },
        'List.empty?'       => ->(xs)          { "#{xs}.empty?" },
        'List.length'       => ->(xs)          { "#{xs}.length" },
        'List.reverse'      => ->(xs)          { "#{xs}.reverse" },
        'List.tail'         => ->(xs)          { "#{xs}.drop(1)" },
        'List.map'          => ->(xs, fn)      { "#{xs}.map(&#{fn})" },
        'List.and_then'     => ->(xs, fn)      { "#{xs}.flat_map(&#{fn})" },
        'List.indexed_map'  => ->(xs, fn)      { "#{xs}.each_with_index.map { |x, i| (#{fn}).(i, x) }" },
        'List.fold'         => ->(xs, init, fn) { "#{xs}.reduce(#{init}, &#{fn})" },
        'List.filter'       => ->(xs, fn)      { "#{xs}.filter(&#{fn})" },
        'List.list_append'  => ->(a, b)        { "(#{a} + #{b})" },
        'List.any?'         => ->(xs, fn)      { "#{xs}.any?(&#{fn})" },
        'List.all?'         => ->(xs, fn)      { "#{xs}.all?(&#{fn})" },
        'List.take'         => ->(xs, n)       { "#{xs}.first([#{n}, 0].max)" },
        'List.drop'         => ->(xs, n)       { "#{xs}.drop([#{n}, 0].max)" },
        'List.concat'       => ->(xs)          { "#{xs}.flatten(1)" },

        'Char.to_code'      => ->(c)           { "#{c}.ord" },
        'Char.from_code'    => ->(code)        { "(Jade::Maybe::Just[#{code}.chr] rescue Jade::Maybe::Nothing[])" },
        'Char.digit?'       => ->(c)           { "#{c}.match?(/\\d/)" },
        'Char.alpha?'       => ->(c)           { "#{c}.match?(/[a-zA-Z]/)" },
        'Char.alpha_numeric?' => ->(c)         { "#{c}.match?(/[a-zA-Z0-9]/)" },
        'Char.upper?'       => ->(c)           { "#{c}.match?(/[A-Z]/)" },
        'Char.lower?'       => ->(c)           { "#{c}.match?(/[a-z]/)" },
        'Char.char_eq'      => ->(a, b)        { "(#{a} == #{b})" },

        'Tuple.pair'        => ->(a, b)        { "Jade::Tuple::Tuple2[#{a}, #{b}]" },
        'Tuple.first'       => ->(t)           { "#{t}._1" },
        'Tuple.second'      => ->(t)           { "#{t}._2" },

        'Bytes.empty'        => ->()            { "Jade::Bytes::Bytes[String.new(encoding: Encoding::BINARY)]" },
        'Bytes.width'        => ->(b)           { "#{b}.bin.bytesize" },
        'Bytes.to_list'      => ->(b)           { "#{b}.bin.bytes" },
        'Bytes.from_string'  => ->(s)           { "Jade::Bytes::Bytes[#{s}.b]" },
        'Bytes.to_string'    => ->(b)           { "#{b}.bin.dup.force_encoding(Encoding::UTF_8).then { it.valid_encoding? ? Jade::Maybe::Just[it] : Jade::Maybe::Nothing[] }" },
        'Bytes.bytes_eq'     => ->(a, b)        { "(#{a}.bin == #{b}.bin)" },
        'Bytes.bytes_append' => ->(a, b)        { "Jade::Bytes::Bytes[#{a}.bin + #{b}.bin]" },
        'Bytes.to_hex'         => ->(b)         { "#{b}.bin.unpack1('H*')" },
        'Bytes.to_base64_url'  => ->(b)         { "::Base64.urlsafe_encode64(#{b}.bin, padding: false)" },

        'Dict.empty'      => ->()           { "Jade::Dict::Dict[{}]" },
        'Dict.singleton'  => ->(k, v)       { "Jade::Dict::Dict[{ #{k} => #{v} }]" },
        'Dict.get'        => ->(d, k)       { "#{d}.hash.then { |h| #{k}.then { |k| h.key?(k) ? Jade::Maybe::Just[h[k]] : Jade::Maybe::Nothing[] } }" },
        'Dict.empty?'     => ->(d)          { "#{d}.hash.empty?" },
        'Dict.size'       => ->(d)          { "#{d}.hash.size" },
        'Dict.member?'    => ->(d, k)       { "#{d}.hash.key?(#{k})" },
        'Dict.insert'     => ->(d, k, v)    { "Jade::Dict::Dict[#{d}.hash.merge(#{k} => #{v})]" },
        'Dict.remove'     => ->(d, k)       { "Jade::Dict::Dict[#{d}.hash.except(#{k})]" },
        'Dict.keys'       => ->(d)          { "#{d}.hash.keys" },
        'Dict.values'     => ->(d)          { "#{d}.hash.values" },
        'Dict.to_list'    => ->(d)          { "#{d}.hash.map { |k, v| Jade::Tuple::Tuple2[k, v] }" },
        'Dict.from_list'  => ->(pairs)      { "Jade::Dict::Dict[#{pairs}.each_with_object({}) { |p, h| h[p._1] = p._2 }]" },
        'Dict.union'      => ->(l, r)       { "Jade::Dict::Dict[#{r}.hash.merge(#{l}.hash)]" },
        'Dict.dict_eq'    => ->(a, b)       { "(#{a}.hash == #{b}.hash)" },

        'Set.empty'       => ->()           { "Jade::Set::Set[{}]" },
        'Set.singleton'   => ->(v)          { "Jade::Set::Set[{ #{v} => true }]" },
        'Set.empty?'      => ->(s)          { "#{s}.hash.empty?" },
        'Set.size'        => ->(s)          { "#{s}.hash.size" },
        'Set.member?'     => ->(s, v)       { "#{s}.hash.key?(#{v})" },
        'Set.insert'      => ->(s, v)       { "Jade::Set::Set[#{s}.hash.merge(#{v} => true)]" },
        'Set.remove'      => ->(s, v)       { "Jade::Set::Set[#{s}.hash.except(#{v})]" },
        'Set.to_list'     => ->(s)          { "#{s}.hash.keys" },
        'Set.from_list'   => ->(xs)         { "Jade::Set::Set[#{xs}.each_with_object({}) { |v, h| h[v] = true }]" },
        'Set.union'       => ->(l, r)       { "Jade::Set::Set[#{l}.hash.merge(#{r}.hash)]" },
        'Set.set_eq'      => ->(a, b)       { "(#{a}.hash == #{b}.hash)" },
      }.freeze

      # Native block form is 2-3× faster than `&lambda` — Ruby skips
      # lambda-to-block conversion per call.
      BLOCK_INLINES = {
        'List.map'         => ->(xs, params, body)         { "#{xs}.map { |#{params}| #{body} }" },
        'List.filter'      => ->(xs, params, body)         { "#{xs}.filter { |#{params}| #{body} }" },
        'List.fold'        => ->(xs, init, params, body)   { "#{xs}.reduce(#{init}) { |#{params}| #{body} }" },
        'List.and_then'    => ->(xs, params, body)         { "#{xs}.flat_map { |#{params}| #{body} }" },
        'List.indexed_map' => ->(xs, params, body)         { "#{xs}.each_with_index.map { |#{params.split(', ').reverse.join(', ')}| #{body} }" },
        'List.any?'        => ->(xs, params, body)         { "#{xs}.any? { |#{params}| #{body} }" },
        'List.all?'        => ->(xs, params, body)         { "#{xs}.all? { |#{params}| #{body} }" },
        'List.find'        => ->(xs, params, body)         { "#{xs}.find { |#{params}| #{body} }.then { |m| m.nil? ? Jade::Maybe::Nothing[] : Jade::Maybe::Just[m] }" },
        'List.partition'   => ->(xs, params, body)         { "Jade::Tuple::Tuple2[*#{xs}.partition { |#{params}| #{body} }]" },
        'String.map'       => ->(s, params, body)          { "#{s}.chars.map { |#{params}| #{body} }.join" },
      }.freeze

      # Bodies that don't fit a single Ruby expression.
      NO_INLINE = %w[
        List.sort_with
        List.sort_by_with
        List.filter_map
        List.zip
        List.member_with
        List.maximum_with
        List.minimum_with
        Decode.and_map
        Decode.and_then
        Decode.bool
        Decode.decode
        Decode.decode_string
        Decode.dict
        Decode.fail
        Decode.field
        Decode.float
        Decode.from_result
        Decode.index
        Decode.int
        Decode.list
        Decode.map
        Decode.nullable
        Decode.one_of
        Decode.optional
        Decode.optional_field
        Decode.required
        Decode.sequence
        Decode.string
        Decode.succeed
        Decode.tuple
        Decode.tuple3
        Decode.tuple4
        Decode.type_
        Decode.variant
        Encode.bool
        Encode.dict
        Encode.encode_to_string
        Encode.field
        Encode.float
        Encode.int
        Encode.list
        Encode.null
        Encode.nullable
        Encode.object
        Encode.string
        Encode.tuple
        Encode.tuple3
        Encode.tuple4
        Encode.variant
        Task.and_then
        Task.fail
        Task.from_result
        Task.map
        Task.map_error
        Task.on_error
        Task.run
        Task.sequence
        Task.succeed
        Bytes.from_list
        Bytes.from_hex
        Bytes.from_base64_url
        Dict.get
        Dict.update
        Dict.map
        Dict.filter
        Dict.fold
        Dict.merge
        Set.map
        Set.filter
        Set.fold
        Set.intersect
        Set.diff
      ].to_set.freeze

      def for(qualified_name)
        INLINES[qualified_name]
      end

      def expected_to_skip?(qualified_name)
        NO_INLINE.include?(qualified_name)
      end

      def block_for(qualified_name)
        BLOCK_INLINES[qualified_name]
      end

      def comparison_for(qualified_name, dictionaries, registry)
        template = DERIVED_COMPARISONS[qualified_name]
        return nil unless template
        return nil unless dictionaries&.first.is_a?(Symbol::Implementation)

        dictionaries.first.functions['compare'].then do |entry|
          next nil unless entry.is_a?(Symbol::ValueRef)

          fn = registry.lookup(entry)
          next nil unless fn.is_a?(Symbol::StdlibFunction)
          next nil unless RUBY_NATIVE_COMPARES.include?("#{fn.module_name}.#{fn.name}")

          template
        end
      end

      def neq_for(qualified_name, dictionaries, registry)
        return nil unless qualified_name == 'Basics.(!=)'
        return nil unless dictionaries&.first.is_a?(Symbol::Implementation)

        dictionaries.first.functions['(==)'].then do |entry|
          next nil unless entry.is_a?(Symbol::ValueRef)

          fn = registry.lookup(entry)
          next nil unless fn.is_a?(Symbol::StdlibFunction)
          next nil unless RUBY_NATIVE_EQS.include?("#{fn.module_name}.#{fn.name}")

          ->(a, b) { "(#{a} != #{b})" }
        end
      end

      def derived_for(qualified_name, dictionaries, registry)
        return nil unless dictionaries&.first in Symbol::Implementation => impl

        case qualified_name
        in 'List.sort' if native_compare?(impl, registry)
          ->(xs) { "#{xs}.sort" }

        in 'List.sort_by' if native_compare?(impl, registry)
          ->(xs, key) { "#{xs}.sort_by(&#{key})" }

        in 'List.maximum' if native_compare?(impl, registry)
          ->(xs) { "#{xs}.max.then { |m| m.nil? ? Jade::Maybe::Nothing[] : Jade::Maybe::Just[m] }" }

        in 'List.minimum' if native_compare?(impl, registry)
          ->(xs) { "#{xs}.min.then { |m| m.nil? ? Jade::Maybe::Nothing[] : Jade::Maybe::Just[m] }" }

        in 'List.member?' if native_eq?(impl, registry)
          ->(xs, e) { "#{xs}.include?(#{e})" }

        else
          nil
        end
      end

      def native_compare?(impl, registry)
        native_impl_fn?(impl, 'compare', RUBY_NATIVE_COMPARES, registry)
      end

      def native_eq?(impl, registry)
        native_impl_fn?(impl, '(==)', RUBY_NATIVE_EQS, registry)
      end

      def native_impl_fn?(impl, fn_name, native_set, registry)
        entry = impl.functions[fn_name]
        return false unless entry.is_a?(Symbol::ValueRef)

        fn = registry.lookup(entry)
        return false unless fn.is_a?(Symbol::StdlibFunction)

        native_set.include?("#{fn.module_name}.#{fn.name}")
      end
    end
  end
end
