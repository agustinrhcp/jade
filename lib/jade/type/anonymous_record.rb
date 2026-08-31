module Jade
  module Type
    AnonymousRecord = Data.define(:fields, :row_var, :display) do
      include Base
      include Displayable

      def initialize(fields:, row_var:, display: nil)
        super
      end

      def identity
        [fields, row_var]
      end

      def render
        row = row_var ? "#{row_var} | " : ""

        fields
          .map { |name, type| "#{name} : #{type}" }
          .join(", ")
          .then { "{ #{row}#{it} }" }
      end

      def unbound_vars
        (row_var ? row_var.unbound_vars : []) +
          fields.values.flat_map(&:unbound_vars).uniq
      end

      def open?
        !closed?
      end

      def closed?
        row_var.nil?
      end

      def field_names
        fields.keys
      end
    end
  end
end
