module Jade
  module Type
    AnonymousRecord = Data.define(:fields, :row_var) do
      include Base

      def to_s
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

      def make_rigid(val = true)
        with(row_var: row_var&.make_rigid(val))
      end
    end
  end
end
