require 'json'

module Jade
  module Decode
    MissingField = Data.define(:_1)
    WrongType    = Data.define(:_1, :_2)
    AtField      = Data.define(:_1, :_2)
    AtIndex      = Data.define(:_1, :_2)
    Multiple     = Data.define(:_1)
    Custom       = Data.define(:_1)

    Decoder = Data.define(:desc)

    # Decoding returns the value itself, or one of these. Never escapes
    # this file: `Runner` turns it into the Result callers see.
    Failure = Struct.new(:error)

    # Distinguishes a key that is absent from one whose value is nil.
    ABSENT = Object.new

    module Desc
      module Node
        def decoded?(v) = !(Failure === v)

        private

        def type_err(expected, got)
          Failure.new(WrongType[expected, Decode.type_name(got)])
        end

        def coerce_hash(value)
          case value
          when ::Hash then value
          when ::Data then value.to_h
          end
        end

        # Ports hand back Symbol-keyed hashes and String-keyed ones, so
        # both are read before deciding a key is absent.
        def at_key(h, sym, key)
          value = h[sym]
          return value unless value.nil?

          value = h[key]
          return value unless value.nil?

          h.key?(sym) || h.key?(key) ? nil : ABSENT
        end

        def at_field(key, result)
          decoded?(result) ? result : Failure.new(AtField[key, result.error])
        end

        def wrap_errors(errors)
          errors.length == 1 ? errors.first : Multiple[errors]
        end
      end

      Str = Data.define() do
        include Node

        def decode(value)
          ::String === value ? value.dup : type_err('String', value)
        end
      end

      Int = Data.define() do
        include Node

        def decode(value)
          ::Integer === value ? value : type_err('Int', value)
        end
      end

      Flt = Data.define() do
        include Node

        def decode(value)
          ::Numeric === value ? value.to_f : type_err('Float', value)
        end
      end

      Bool = Data.define() do
        include Node

        def decode(value)
          value == true || value == false ? value : type_err('Bool', value)
        end
      end

      Pass = Data.define() do
        include Node

        def decode(value) = value
      end

      Nullable = Data.define(:inner) do
        include Node

        def decode(value)
          return Jade::Maybe::Nothing[] if value.nil?

          decoded = inner.decode(value)
          decoded?(decoded) ? Jade::Maybe::Just[decoded] : decoded
        end
      end

      Field = Data.define(:key, :inner) do
        include Node

        def decode(value)
          h = coerce_hash(value)
          return type_err('Object', value) unless h

          raw = at_key(h, key.to_sym, key)
          return Failure.new(MissingField[key.to_s]) if ABSENT.equal?(raw)

          at_field(key.to_s, inner.decode(raw))
        end
      end

      OptField = Data.define(:key, :inner) do
        include Node

        def decode(value)
          h = coerce_hash(value)
          return type_err('Object', value) unless h

          raw = at_key(h, key.to_sym, key)
          return Jade::Maybe::Nothing[] if ABSENT.equal?(raw)

          decoded = inner.decode(raw)
          decoded?(decoded) ? Jade::Maybe::Just[decoded] : Failure.new(AtField[key.to_s, decoded.error])
        end
      end

      Optional = Data.define(:key, :inner, :default) do
        include Node

        def decode(value)
          h = coerce_hash(value)
          return type_err('Object', value) unless h

          raw = at_key(h, key.to_sym, key)
          return default if ABSENT.equal?(raw) || raw.nil?

          at_field(key.to_s, inner.decode(raw))
        end
      end

      Idx = Data.define(:index, :inner) do
        include Node

        def decode(value)
          return type_err('Array', value) unless ::Array === value
          return Failure.new(MissingField["[#{index}]"]) if index >= value.length

          decoded = inner.decode(value[index])
          decoded?(decoded) ? decoded : Failure.new(AtIndex[index, decoded.error])
        end
      end

      Lst = Data.define(:inner) do
        include Node

        def decode(value)
          return type_err('Array', value) unless ::Array === value

          size = value.length
          values = ::Array.new(size)
          errors = nil
          i = 0

          while i < size
            decoded = inner.decode(value[i])
            decoded?(decoded) ? values[i] = decoded : (errors ||= []) << AtIndex[i, decoded.error]
            i += 1
          end

          errors ? Failure.new(wrap_errors(errors)) : values
        end
      end

      RecordField = Data.define(:key, :sym, :inner)

      Record = Data.define(:fields, :ctor) do
        include Node

        # Spells out `at_key` and `decoded?` rather than calling them:
        # this runs once per field of every decoded row.
        def decode(value)
          h = coerce_hash(value)
          return type_err('Object', value) unless h

          size = fields.length
          args = ::Array.new(size)
          errors = nil
          i = 0

          while i < size
            field = fields[i]
            key = field.key
            sym = field.sym
            raw = h[sym]
            raw = h[key] if raw.nil?

            if raw.nil? && !h.key?(sym) && !h.key?(key)
              (errors ||= []) << MissingField[key]
            else
              decoded = field.inner.decode(raw)
              Failure === decoded ? (errors ||= []) << AtField[key, decoded.error] : args[i] = decoded
            end
            i += 1
          end

          errors ? Failure.new(wrap_errors(errors)) : ctor.new(*args)
        end
      end

      # `Record` by position: N indices of an array into an N-argument
      # constructor. What the tuple decoders are built from.
      Indexed = Data.define(:inners, :ctor) do
        include Node

        def decode(value)
          return type_err('Array', value) unless ::Array === value

          size = inners.length
          given = value.length
          args = ::Array.new(size)
          errors = nil
          i = 0

          while i < size
            if i >= given
              (errors ||= []) << MissingField["[#{i}]"]
            else
              decoded = inners[i].decode(value[i])
              Failure === decoded ? (errors ||= []) << AtIndex[i, decoded.error] : args[i] = decoded
            end
            i += 1
          end

          errors ? Failure.new(wrap_errors(errors)) : ctor.new(*args)
        end
      end

      # `parse` returns the value, or nil when the text is malformed.
      FromString = Data.define(:label, :parse) do
        include Node

        def decode(value)
          return type_err(label, value) unless ::String === value

          parsed = parse.call(value)
          parsed.nil? ? Failure.new(Custom["invalid #{label}: #{value}"]) : parsed
        end
      end

      Dct = Data.define(:k_inner, :v_inner) do
        include Node

        # Two accepted wire shapes for Dict: a Hash (the natural Ruby form
        # and what String-keyed JSON parses to) and an Array of [k, v]
        # pairs (the form Encode.dict emits — survives non-String keys).
        def decode(value)
          if (h = coerce_hash(value))
            entries(h.each_pair.map { |k, v| [[k, v], k.to_s] }, :at_field)
          elsif ::Array === value
            entries(value.each_with_index.map { |pair, i| [pair, i] }, :at_index)
          else
            type_err('Object or Array', value)
          end
        end

        private

        def entries(pairs, position)
          h = {}
          errors = []

          pairs.each do |pair, pos|
            case pair
            in [k_raw, v_raw]
              k = k_inner.decode(k_raw)
              v = v_inner.decode(v_raw)

              if decoded?(k) && decoded?(v)
                h[k] = v
              else
                [k, v].each { errors << wrap_pos(position, pos, it.error) unless decoded?(it) }
              end

            else
              errors << wrap_pos(position, pos, WrongType['Array[2]', Decode.type_name(pair)])
            end
          end

          errors.empty? ? Jade::Dict::Dict[h] : Failure.new(wrap_errors(errors))
        end

        def wrap_pos(position, pos, inner)
          position == :at_index ? AtIndex[pos, inner] : AtField[pos, inner]
        end
      end

      Map = Data.define(:fn, :d) do
        include Node

        def decode(value)
          decoded = d.decode(value)
          decoded?(decoded) ? fn.call(decoded) : decoded
        end
      end

      Succeed = Data.define(:value) do
        include Node

        def decode(_value) = value
      end

      AndMap = Data.define(:wrapped, :value_d) do
        include Node

        def decode(value)
          fn = wrapped.decode(value)
          arg = value_d.decode(value)

          return fn.call(arg) if decoded?(fn) && decoded?(arg)

          [fn, arg]
            .reject { decoded?(it) }
            .map(&:error)
            .then { Failure.new(wrap_errors(it)) }
        end
      end

      Sequence = Data.define(:decoders) do
        include Node

        def decode(value)
          results = decoders.map { it.decode(value) }
          errors = results.reject { decoded?(it) }

          errors.empty? ? results : Failure.new(wrap_errors(errors.map(&:error)))
        end
      end

      OneOf = Data.define(:decoders) do
        include Node

        def decode(value)
          errors = []

          decoders.each do
            decoded = it.decode(value)
            return decoded if decoded?(decoded)

            errors << decoded.error
          end

          Failure.new(wrap_errors(errors))
        end
      end

      AndThen = Data.define(:fn, :d) do
        include Node

        def decode(value)
          decoded = d.decode(value)
          decoded?(decoded) ? fn.call(decoded).desc.decode(value) : decoded
        end
      end

      Fail = Data.define(:msg) do
        include Node

        def decode(_value) = Failure.new(Custom[msg])
      end

      Variant = Data.define(:cases) do
        include Node

        def decode(value)
          return type_err('Array', value) unless ::Array === value
          return Failure.new(Custom['empty variant array']) if value.empty?

          tag = value.first
          return type_err('String tag at index 0', tag) unless ::String === tag

          inner = cases[tag]
          return Failure.new(Custom["unknown variant: #{tag.inspect}"]) unless inner

          inner.decode(value)
        end
      end
    end

    module Runner
      extend self

      def from_json(decoder, json_string)
        begin
          parsed = JSON.parse(json_string)
        rescue JSON::ParserError => e
          return Jade::Result::Err[Jade::Decode::WrongType['valid JSON', e.message]]
        end
        run(decoder, parsed)
      end

      def run(decoder, value)
        decoded = decoder.desc.decode(value)

        Failure === decoded ? Jade::Result::Err[decoded.error] : Jade::Result::Ok[decoded]
      end

      # The decoded value or a raise — no Result for the caller to unwrap.
      def run!(decoder, value)
        decoded = decoder.desc.decode(value)

        Failure === decoded ? yield(decoded.error) : decoded
      end
    end

    # Public so specialized boundary decoders can emit error values matching
    # the interpreter's `WrongType` format without going through `Runner`.
    def self.type_name(v)
      case v
      when ::String              then "String"
      when ::Integer             then "Int"
      when ::Float               then "Float"
      when TrueClass, FalseClass then "Bool"
      when ::NilClass            then "null"
      when ::Array               then "Array"
      when ::Hash                then "Object"
      else                            v.class.name
      end
    end
  end
end
