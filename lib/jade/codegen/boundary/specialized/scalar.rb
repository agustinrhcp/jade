module Jade
  module Codegen
    module Boundary
      module Specialized
        # Int / Float / Bool / String. The runtime validators in
        # `Jade::Interop::Boundary` do the check + conversion (e.g.
        # `String#dup`, `Float#to_f`) in one call.
        module Scalar
          extend self

          HELPER = {
            'Basics.Int'    => 'integer',
            'Basics.Float'  => 'float',
            'Basics.Bool'   => 'bool',
            'String.String' => 'string',
          }.freeze

          LABEL = {
            'Basics.Int'    => 'Int',
            'Basics.Float'  => 'Float',
            'Basics.Bool'   => 'Bool',
            'String.String' => 'String',
          }.freeze

          # Ruby class used by `List.decode` to validate a list of scalars
          # in a single `Array#all?` C-loop.
          LIST_ELEM_CLASS = {
            'Basics.Int'    => '::Integer',
            'Basics.Float'  => '::Numeric',
            'Basics.Bool'   => '::TrueClass',
            'String.String' => '::String',
          }.freeze

          def decode(type, input)
            qname = qname_for(type) or return nil
            label = LABEL[qname].inspect
            "Jade::Interop::Boundary.#{HELPER[qname]}(#{label}, #{input})"
          end

          # Scalar encoders are identity (Ruby int IS the JSON int, etc.),
          # so `encode` returns nil — callers handle that via
          # `Specialized.identity_encoder?`.
          def encode(_type, _value_expr, _registry)
            nil
          end

          def identity_encoder?(type)
            qname_for(type) ? true : false
          end

          def specializable?(type, _registry, _seen)
            identity_encoder?(type)
          end

          # The scalar's qname (e.g. `"Basics.Int"`) if `type` is a 0-arg
          # application of a known scalar constructor, else nil. Used by
          # `List.decode` to pick `LIST_ELEM_CLASS` for the all? check.
          def qname_for(type)
            return nil unless Specialized.args_of(type) == []

            Specialized.qname_of(type).then { HELPER.key?(it) ? it : nil }
          end
        end
      end
    end
  end
end
