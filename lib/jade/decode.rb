require 'json'

module Decode
  MissingField = Data.define(:_1)
  WrongType    = Data.define(:_1, :_2)
  AtField      = Data.define(:_1, :_2)
  AtIndex      = Data.define(:_1, :_2)
  Multiple     = Data.define(:_1)

  Decoder = Data.define(:desc)
  Value   = Data.define(:_1)

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
  end

  module Runner
    extend self

    def from_json(decoder, json_string)
      begin
        parsed = JSON.parse(json_string)
      rescue JSON::ParserError => e
        return err(::Decode::WrongType["valid JSON", e.message])
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
          in ::Result::Ok[v] then ok(just(v))
          in ::Result::Err => e then e
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
          err(::Decode::MissingField[key.to_s])
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
          in ::Result::Ok => r  then r
          in ::Result::Err[e]   then err(::Decode::AtField[key.to_s, e])
          end
        end

      in Desc::Idx[index, inner]
        arr = coerce_array(value)
        return type_err("Array", value) unless arr
        return err(::Decode::MissingField["[#{index}]"]) if index >= arr.length

        case interp(inner, arr[index])
        in ::Result::Ok => r  then r
        in ::Result::Err[e]   then err(::Decode::AtIndex[index, e])
        end

      in Desc::Lst[inner]
        arr = coerce_array(value)
        return type_err("Array", value) unless arr

        values = []
        errors = []
        arr.each_with_index do |v, i|
          case interp(inner, v)
          in ::Result::Ok[decoded] then values << decoded
          in ::Result::Err[e]      then errors << ::Decode::AtIndex[i, e]
          end
        end
        errors.empty? ? ok(values) : err(wrap_errors(errors))

      in Desc::Map[fn, d]
        case interp(d, value)
        in ::Result::Ok[v] then ok(fn.call(v))
        in ::Result::Err => e then e
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
          in ::Result::Ok => r  then return r
          in ::Result::Err[e]   then errors << e
          end
        end
        err(wrap_errors(errors))
      end
    end

    def ok(v)  = ::Result::Ok[v]
    def err(e) = ::Result::Err[e]
    def nothing = ::Maybe::Nothing[]
    def just(v) = ::Maybe::Just[v]

    def type_err(expected, got)
      err(::Decode::WrongType[expected, ruby_type_name(got)])
    end

    def wrap_at_field(key, result)
      case result
      in ::Result::Ok => r  then r
      in ::Result::Err[e]   then err(::Decode::AtField[key.to_s, e])
      end
    end

    def wrap_opt_at_field(key, result)
      case result
      in ::Result::Ok[v]  then ok(just(v))
      in ::Result::Err[e] then err(::Decode::AtField[key.to_s, e])
      end
    end

    def combine(results, &block)
      values = []
      errors = []
      results.each do |r|
        case r
        in ::Result::Ok[v]  then values << v
        in ::Result::Err[e] then errors << e
        end
      end
      errors.empty? ? ok(block.call(values)) : err(wrap_errors(errors))
    end

    def wrap_errors(errors)
      errors.length == 1 ? errors.first : ::Decode::Multiple[errors]
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
