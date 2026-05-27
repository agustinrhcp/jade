module Jade
  module Codegen
    module Boundary
      # Emits validator calls into `Jade::Interop::Boundary` for known-shape
      # types — `Int`, `Float`, `Bool`, `String`, and `List(scalar)`. The
      # validators bypass `Decode::Runner` entirely, so a 1000-element
      # `List(Int)` becomes a single `Array#all?` C-loop instead of 1000
      # recursive `interp` calls. Returns `nil` for types we don't
      # specialize; the caller falls back to the cached descriptor path.
      module Specialized
        extend self

        SCALAR_HELPER = {
          'Basics.Int'    => 'integer',
          'Basics.Float'  => 'float',
          'Basics.Bool'   => 'bool',
          'String.String' => 'string',
        }.freeze

        SCALAR_LABEL = {
          'Basics.Int'    => 'Int',
          'Basics.Float'  => 'Float',
          'Basics.Bool'   => 'Bool',
          'String.String' => 'String',
        }.freeze

        LIST_ELEM_CLASS = {
          'Basics.Int'    => '::Integer',
          'Basics.Float'  => '::Numeric',
          'Basics.Bool'   => '::TrueClass',
          'String.String' => '::String',
        }.freeze

        # Returns a Ruby expression that validates `input` and yields the
        # decoded value, or `nil` if `type` isn't specializable.
        def decode_expr(type, input)
          if (qname = scalar_qname(type))
            scalar_call(qname, input)
          elsif (qname = list_scalar_qname(type))
            list_call(qname, input)
          end
        end

        # True when the encoder for `type` is the identity function — the
        # boundary wrapper can skip the encode call entirely.
        def identity_encoder?(type)
          scalar_qname(type) || list_scalar_qname(type) ? true : false
        end

        private

        def scalar_qname(type)
          return nil unless type in Type::Application(
            constructor: Type::Constructor(name:),
            args: [],
          )

          SCALAR_HELPER.key?(name) ? name : nil
        end

        def list_scalar_qname(type)
          return nil unless type in Type::Application(
            constructor: Type::Constructor(name: 'List.List'),
            args: [inner],
          )

          scalar_qname(inner)
        end

        def scalar_call(qname, input)
          helper = SCALAR_HELPER[qname]
          label  = SCALAR_LABEL[qname].inspect
          "Jade::Interop::Boundary.#{helper}(#{label}, #{input})"
        end

        def list_call(inner_qname, input)
          klass = LIST_ELEM_CLASS[inner_qname]
          label = "List(#{SCALAR_LABEL[inner_qname]})".inspect
          "Jade::Interop::Boundary.list_of(#{klass}, #{label}, #{input})"
        end
      end
    end
  end
end
