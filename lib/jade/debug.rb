module Jade
  module Debug
    extend self

    MAX_DEPTH = 12

    def log(label, value)
      warn("#{label}: #{render(value)}")
      value
    end

    def render(value, depth = 0)
      return '…' if depth > MAX_DEPTH

      case value
      when ::String then value.inspect
      when ::Symbol then value.to_s
      when nil then 'Nothing'
      when true, false, ::Integer, ::Float then value.to_s
      when ::Array then render_list(value, depth)
      when ::Hash then render_record(value, depth)
      when ::Data then render_variant(value, depth)
      when ::Proc then '<function>'
      else value.inspect
      end
    end

    private

    def render_list(items, depth)
      '[' + items.map { render(it, depth + 1) }.join(', ') + ']'
    end

    def render_record(fields, depth)
      return '{}' if fields.empty?

      '{ ' + fields.map { |k, v| "#{k}: #{render(v, depth + 1)}" }.join(', ') + ' }'
    end

    def render_variant(value, depth)
      name = constructor_name(value)
      args = value.deconstruct

      return '(' + args.map { render(it, depth + 1) }.join(', ') + ')' if name.match?(/\ATuple\d+\z/)
      return name if args.empty?
      return "#{name}(#{args.map { render(it, depth + 1) }.join(', ')})" if positional?(value)

      "#{name} " + render_record(value.to_h, depth)
    end

    def positional?(value)
      value.members.each_with_index.all? { |m, i| m.to_s == "_#{i + 1}" }
    end

    def constructor_name(value)
      value.class.name.to_s.split('::').last.then { it.empty? ? 'Anonymous' : it }
    end
  end
end
