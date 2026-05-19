require 'set'

module Jade
  module ModuleLoader
    # Strips source positions from a nested Data tree so equivalent shapes
    # produce equal byte sequences. Used to compute interface digests that
    # survive whitespace and unrelated edits.
    module Normalize
      extend self

      POSITION_FIELDS = %i[decl_span span range origin].freeze

      def apply(value)
        case value
        when Data  then normalize_data(value)
        when Hash  then value.transform_values { apply(it) }
        when Array then value.map { apply(it) }
        when Set   then value.map { apply(it) }.to_set
        else value
        end
      end

      private

      def normalize_data(value)
        value
          .class
          .members
          .to_h { |m| [m, POSITION_FIELDS.include?(m) ? nil : apply(value.public_send(m))] }
          .then { value.class.new(**it) }
      end
    end
  end
end
