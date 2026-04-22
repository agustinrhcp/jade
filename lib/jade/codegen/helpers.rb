module Jade
  module Codegen
    module Helpers
      extend self

      def generate_many(nodes, registry, sep = ", ")
        nodes.map do
          next yield(it) if block_given?

          generate_node(it, registry)
        end.join(sep)
      end

      def to_qualified(module_name)
        "#{module_name.gsub('.', '::')}"
      end

      def data_define(fields)
        return "Data.define" if fields.empty?

        "Data.define(#{fields.map { ":#{it}" }.join(', ')})"
      end

      def generate_node(node, registry)
        Codegen.generate(node, registry)
      end

      def param_synthetic_name(index)
        "__p#{index}__"
      end

      def impl_synthetic_name(interface, type_name, fn_name)
        sanitized = fn_name.gsub(/[^a-zA-Z0-9_]/) { |c| "x#{c.ord.to_s(16)}" }
        "__impl_#{interface}_#{type_name}_#{sanitized}__"
      end

    def lower_to_ruby(value)
      case value
      in String
        value.dump

      in Array
        value
          .map { |v| lower_to_ruby(v) }.join(", ")
          .then { "[#{it}]" }

      in Hash
        value
          .map { |k, v| "#{lower_to_ruby(k)} => #{lower_to_ruby(v)}" }
          .join(", ")
          .then { "{ #{it}}" }
      end
    end
    end
  end
end
