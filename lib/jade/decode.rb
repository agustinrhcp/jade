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

    module Desc
      Str      = Data.define()
      Int      = Data.define()
      Flt      = Data.define()
      Bool     = Data.define()
      Nullable = Data.define(:inner)
      Field    = Data.define(:key, :inner)
      OptField = Data.define(:key, :inner)
      Optional = Data.define(:key, :inner, :default)
      Idx      = Data.define(:index, :inner)
      Lst      = Data.define(:inner)
      Map      = Data.define(:fn, :d)
      Succeed  = Data.define(:value)
      AndMap   = Data.define(:wrapped, :value_d)
      Sequence = Data.define(:decoders)
      OneOf    = Data.define(:decoders)
      AndThen  = Data.define(:fn, :d)
      Fail     = Data.define(:msg)
    end

    module Runner
      extend self

      def from_json(decoder, json_string)
        begin
          parsed = JSON.parse(json_string)
        rescue JSON::ParserError => e
          return err(Jade::Decode::WrongType["valid JSON", e.message])
        end
        run(decoder, parsed)
      end

      def run(decoder, value)
        interp(decoder.desc, value)
      end

      private

      def interp(desc, value)
        case desc
        in Desc::Str[]
          value.is_a?(::String) ? ok(value.dup) : type_err("String", value)

        in Desc::Int[]
          value.is_a?(::Integer) && !value.is_a?(::Float) ? ok(value) : type_err("Int", value)

        in Desc::Flt[]
          value.is_a?(::Numeric) ? ok(value.to_f) : type_err("Float", value)

        in Desc::Bool[]
          value == true || value == false ? ok(value) : type_err("Bool", value)

        in Desc::Nullable[inner]
          if value.nil?
            ok(nothing)
          else
            case interp(inner, value)
            in Jade::Result::Ok[v] then ok(just(v))
            in Jade::Result::Err => e then e
            end
          end

        in Desc::Field[key, inner]
          h = coerce_hash(value)
          return type_err("Object", value) unless h

          sym = key.to_sym
          if h.key?(sym)
            wrap_at_field(key, interp(inner, h[sym]))
          elsif h.key?(key)
            wrap_at_field(key, interp(inner, h[key]))
          else
            err(Jade::Decode::MissingField[key.to_s])
          end

        in Desc::OptField[key, inner]
          h = coerce_hash(value)
          return type_err("Object", value) unless h

          sym = key.to_sym
          if h.key?(sym)
            wrap_opt_at_field(key, interp(inner, h[sym]))
          elsif h.key?(key)
            wrap_opt_at_field(key, interp(inner, h[key]))
          else
            ok(nothing)
          end

        in Desc::Optional[key, inner, default]
          h = coerce_hash(value)
          return type_err("Object", value) unless h

          sym = key.to_sym
          raw = h.fetch(sym) { h.fetch(key) { :__absent__ } }

          if raw == :__absent__ || raw.nil?
            ok(default)
          else
            case interp(inner, raw)
            in Jade::Result::Ok => r  then r
            in Jade::Result::Err[e]   then err(Jade::Decode::AtField[key.to_s, e])
            end
          end

        in Desc::Idx[index, inner]
          arr = coerce_array(value)
          return type_err("Array", value) unless arr
          return err(Jade::Decode::MissingField["[#{index}]"]) if index >= arr.length

          case interp(inner, arr[index])
          in Jade::Result::Ok => r  then r
          in Jade::Result::Err[e]   then err(Jade::Decode::AtIndex[index, e])
          end

        in Desc::Lst[inner]
          arr = coerce_array(value)
          return type_err("Array", value) unless arr

          values = []
          errors = []
          arr.each_with_index do |v, i|
            case interp(inner, v)
            in Jade::Result::Ok[decoded] then values << decoded
            in Jade::Result::Err[e]      then errors << Jade::Decode::AtIndex[i, e]
            end
          end
          errors.empty? ? ok(values) : err(wrap_errors(errors))

        in Desc::Map[fn, d]
          case interp(d, value)
          in Jade::Result::Ok[v] then ok(fn.call(v))
          in Jade::Result::Err => e then e
          end

        in Desc::Succeed[v]
          ok(v)

        in Desc::AndMap[wrapped, value_d]
          combine([interp(wrapped, value), interp(value_d, value)]) { |fn_and_a|
            fn, a = fn_and_a
            fn.call(a)
          }

        in Desc::Sequence[ds]
          combine(ds.map { interp(it, value) }) { it }

        in Desc::OneOf[ds]
          errors = []
          ds.each do |d|
            case interp(d, value)
            in Jade::Result::Ok => r  then return r
            in Jade::Result::Err[e]   then errors << e
            end
          end
          err(wrap_errors(errors))

        in Desc::AndThen[fn, d]
          case interp(d, value)
          in Jade::Result::Ok[v]    then interp(fn.call(v).desc, value)
          in Jade::Result::Err => e then e
          end

        in Desc::Fail[msg]
          err(Jade::Decode::Custom[msg])
        end
      end

      def ok(v)  = Jade::Result::Ok[v]
      def err(e) = Jade::Result::Err[e]
      def nothing = Jade::Maybe::Nothing[]
      def just(v) = Jade::Maybe::Just[v]

      def type_err(expected, got)
        err(Jade::Decode::WrongType[expected, ruby_type_name(got)])
      end

      def wrap_at_field(key, result)
        case result
        in Jade::Result::Ok => r  then r
        in Jade::Result::Err[e]   then err(Jade::Decode::AtField[key.to_s, e])
        end
      end

      def wrap_opt_at_field(key, result)
        case result
        in Jade::Result::Ok[v]  then ok(just(v))
        in Jade::Result::Err[e] then err(Jade::Decode::AtField[key.to_s, e])
        end
      end

      def combine(results, &block)
        values = []
        errors = []
        results.each do |r|
          case r
          in Jade::Result::Ok[v]  then values << v
          in Jade::Result::Err[e] then errors << e
          end
        end
        errors.empty? ? ok(block.call(values)) : err(wrap_errors(errors))
      end

      def wrap_errors(errors)
        errors.length == 1 ? errors.first : Jade::Decode::Multiple[errors]
      end

      def coerce_hash(value)
        case value
        when ::Hash then value
        when ::Data then value.to_h
        else nil
        end
      end

      def coerce_array(value)
        value.is_a?(::Array) ? value : nil
      end

      def ruby_type_name(v)
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
end
