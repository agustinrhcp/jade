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
        'Basics.(&&)'       => ->(a, b) { "(#{a} && #{b})" },
        'Basics.(||)'       => ->(a, b) { "(#{a} || #{b})" },
        'Basics.not'        => ->(a)    { "(!#{a})" },
        'Basics.int_eq'     => ->(a, b) { "(#{a} == #{b})" },
        'Basics.float_eq'   => ->(a, b) { "(#{a} == #{b})" },
        'Basics.bool_eq'    => ->(a, b) { "(#{a} == #{b})" },

        'String.str_append' => ->(a, b)        { "(#{a} + #{b})" },
        'String.str_eq'     => ->(a, b)        { "(#{a} == #{b})" },
        'String.is_empty'   => ->(s)           { "#{s}.empty?" },
        'String.length'     => ->(s)           { "#{s}.length" },
        'String.reverse'    => ->(s)           { "#{s}.reverse" },
        'String.cons'       => ->(head, tail)  { "(#{head} + #{tail})" },
        'String.from_char'  => ->(c)           { c },
        'String.from_int'   => ->(n)           { "#{n}.to_s" },
        'String.repeat'     => ->(s, n)        { "(#{s} * #{n})" },
        'String.split'      => ->(s, by)       { "#{s}.split(#{by})" },
        'String.concat'     => ->(xs)          { "#{xs}.join" },
        'String.join'       => ->(xs, with)    { "#{xs}.join(#{with})" },
        'String.map'        => ->(s, fn)       { "#{s}.chars.map(&#{fn}).join" },

        'List.singleton'    => ->(x)           { "[#{x}]" },
        'List.repeat'       => ->(x, n)        { "([#{x}] * #{n})" },
        'List.range'        => ->(lo, hi)      { "(#{lo}..#{hi}).to_a" },
        'List.is_empty'     => ->(xs)          { "#{xs}.empty?" },
        'List.length'       => ->(xs)          { "#{xs}.length" },
        'List.tail'         => ->(xs)          { "#{xs}.drop(1)" },
        'List.map'          => ->(xs, fn)      { "#{xs}.map(&#{fn})" },
        'List.and_then'     => ->(xs, fn)      { "#{xs}.flat_map(&#{fn})" },
        'List.indexed_map'  => ->(xs, fn)      { "#{xs}.map.with_index(&#{fn})" },
        'List.fold'         => ->(xs, init, fn) { "#{xs}.reduce(#{init}, &#{fn})" },
        'List.filter'       => ->(xs, fn)      { "#{xs}.filter(&#{fn})" },
        'List.list_append'  => ->(a, b)        { "(#{a} + #{b})" },

        'Char.to_code'      => ->(c)           { "#{c}.ord" },
        'Char.is_digit'     => ->(c)           { "#{c}.match?(/\\d/)" },
        'Char.is_alpha'     => ->(c)           { "#{c}.match?(/[a-zA-Z]/)" },
        'Char.is_alpha_num' => ->(c)           { "#{c}.match?(/[a-zA-Z0-9]/)" },
        'Char.is_upper'     => ->(c)           { "#{c}.match?(/[A-Z]/)" },
        'Char.is_lower'     => ->(c)           { "#{c}.match?(/[a-z]/)" },
        'Char.char_eq'      => ->(a, b)        { "(#{a} == #{b})" },

        'Tuple.first'       => ->(t)           { "#{t}._1" },
        'Tuple.second'      => ->(t)           { "#{t}._2" },

        'Dict.empty'      => ->()           { "Jade::Dict::Dict[{}]" },
        'Dict.singleton'  => ->(k, v)       { "Jade::Dict::Dict[{ #{k} => #{v} }]" },
        'Dict.is_empty'   => ->(d)          { "#{d}.hash.empty?" },
        'Dict.size'       => ->(d)          { "#{d}.hash.size" },
        'Dict.member'     => ->(d, k)       { "#{d}.hash.key?(#{k})" },
        'Dict.insert'     => ->(d, k, v)    { "Jade::Dict::Dict[#{d}.hash.merge(#{k} => #{v})]" },
        'Dict.keys'       => ->(d)          { "#{d}.hash.keys" },
        'Dict.values'     => ->(d)          { "#{d}.hash.values" },
        'Dict.to_list'    => ->(d)          { "#{d}.hash.map { |k, v| Jade::Tuple::Tuple2[k, v] }" },
        'Dict.from_list'  => ->(pairs)      { "Jade::Dict::Dict[#{pairs}.each_with_object({}) { |p, h| h[p._1] = p._2 }]" },
        'Dict.union'      => ->(l, r)       { "Jade::Dict::Dict[#{r}.hash.merge(#{l}.hash)]" },
        'Dict.dict_eq'    => ->(a, b)       { "(#{a}.hash == #{b}.hash)" },
      }.freeze

      # Native block form is 2-3× faster than `&lambda` — Ruby skips
      # lambda-to-block conversion per call.
      BLOCK_INLINES = {
        'List.map'         => ->(xs, params, body)         { "#{xs}.map { |#{params}| #{body} }" },
        'List.filter'      => ->(xs, params, body)         { "#{xs}.filter { |#{params}| #{body} }" },
        'List.fold'        => ->(xs, init, params, body)   { "#{xs}.reduce(#{init}) { |#{params}| #{body} }" },
        'List.and_then'    => ->(xs, params, body)         { "#{xs}.flat_map { |#{params}| #{body} }" },
        'List.indexed_map' => ->(xs, params, body)         { "#{xs}.each_with_index.map { |#{params}| #{body} }" },
        'String.map'       => ->(s, params, body)          { "#{s}.chars.map { |#{params}| #{body} }.join" },
      }.freeze

      # Bodies that don't fit a single Ruby expression.
      NO_INLINE = %w[
        Basics.int_compare
        Basics.float_compare
        String.str_compare
        List.head
        String.uncons
        String.to_int
        Char.from_code
        List._sort_with
        List._sort_by_with
        Tuple.pair
        Decode.and_map
        Decode.and_then
        Decode.bool
        Decode.decode
        Decode.decode_string
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
        Dict.get
        Dict.remove
        Dict.update
        Dict.map
        Dict.filter
        Dict.fold
        Dict.merge
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
    end
  end
end
