module Jade
  module Repl
    # A value the way it would be written in Jade, steered by its type: at
    # runtime a Char is a String and a Dict is a Data wrapping a Hash. Inside
    # a user's own types the runtime shape decides, since the field types are
    # not threaded that far.
    module Printer
      extend self

      LIMIT = 100

      def render(value, type = nil)
        case type
        in Type::Application(constructor: Type::Constructor(name:), args:)
          application(value, name, args)

        in Type::Function
          '<function>'

        in Type::AnonymousRecord(fields:)
          record(value, fields)

        else
          runtime(value)
        end
      end

      private

      def application(value, name, args)
        case [name, args]
        in ['Char.Char', []] then "'#{value.inspect[1...-1]}'"
        in ['Basics.Unit', []] then '()'
        in ['List.List', [item]] then list(value, item)
        in ['Maybe.Maybe', [item]] then variant(value, [item])
        in ['Result.Result', [ok, err]] then variant(value, [ok?(value) ? ok : err])
        in ['Dict.Dict', [key, item]] then dict(value, key, item)
        in ['Set.Set', [item]] then "Set.from_list(#{list(value.hash.keys, item)})"
        in ['Task.Task', _] then '<task>'
        in [/\ATuple\.Tuple\d\z/, items] then tuple(value.deconstruct, items)
        else runtime(value)
        end
      end

      def runtime(value)
        case value
        when true then 'True'
        when false then 'False'
        when ::String then value.inspect
        when ::Array then list(value, nil)
        when ::Proc, ::Method then '<function>'
        when Jade::Dict::Dict then dict(value, nil, nil)
        when Jade::Set::Set then application(value, 'Set.Set', [nil])
        when *TUPLES then tuple(value.deconstruct, [])
        when ::Data then data(value)
        else value.to_s
        end
      end

      TUPLES = [Jade::Tuple::Tuple2, Jade::Tuple::Tuple3, Jade::Tuple::Tuple4].freeze

      def list(values, item)
        values
          .first(LIMIT)
          .map { render(it, item) }
          .then { values.size > LIMIT ? it + ['…'] : it }
          .then { "[#{it.join(', ')}]" }
      end

      def tuple(values, types)
        values
          .each_with_index
          .map { |value, i| render(value, types[i]) }
          .then { "(#{it.join(', ')})" }
      end

      def dict(value, key, item)
        value
          .hash
          .first(LIMIT)
          .map { |k, v| "(#{render(k, key)}, #{render(v, item)})" }
          .then { value.hash.size > LIMIT ? it + ['…'] : it }
          .then { "Dict.from_list([#{it.join(', ')}])" }
      end

      def variant(value, types)
        value
          .deconstruct
          .each_with_index
          .map { |arg, i| render(arg, types[i]) }
          .then { it.empty? ? constructor(value) : "#{constructor(value)}(#{it.join(', ')})" }
      end

      def record(value, fields)
        value
          .to_h
          .map { |key, field| "#{key}: #{render(field, fields&.[](key.to_s))}" }
          .then { "{ #{it.join(', ')} }" }
      end

      def data(value)
        return record(value, nil) if value.class.name.to_s.start_with?('Jade::Records::')
        return variant(value, []) if positional?(value.class.members)

        value
          .class
          .members
          .map { "#{it}: #{render(value.public_send(it))}" }
          .then { "#{constructor(value)}(#{it.join(', ')})" }
      end

      def positional?(members)
        members
          .each_with_index
          .all? { |member, i| member == :"_#{i + 1}" }
      end

      def ok?(value)
        constructor(value) == 'Ok'
      end

      def constructor(value)
        value.class.name.split('::').last
      end
    end
  end
end
