module Jade
  module Codegen
    module Boundary
      # Emits inline boundary code for known-shape types — `Int`, `Float`,
      # `Bool`, `String`, `List(scalar)`, and structs whose fields are all
      # scalar/list-of-scalar. Bypasses `Decode::Runner` and the descriptor
      # cache entirely. For structs, emits a pair of `decode_<name>` /
      # `encode_<name>` helper methods at module level; wrapper bodies call
      # those instead of nested `decode_or_raise` / encoder closures.
      module Specialized
        extend self
        extend Helpers

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
        def decode_expr(type, input, registry)
          if (qname = scalar_qname(type))
            scalar_call(qname, input)
          elsif (qname = list_scalar_qname(type))
            list_call(qname, input)
          elsif (struct = record_struct(type, registry))
            "#{decode_helper_name(struct)}(#{input})"
          end
        end

        # Returns a Ruby expression that encodes `value_expr` to the wire
        # form, or `nil` if `type` isn't a record (scalars/lists go through
        # `identity_encoder?` + skip; everything else falls back to the
        # cached encoder closure).
        def encode_expr(type, value_expr, registry)
          struct = record_struct(type, registry) or return nil
          "#{encode_helper_name(struct)}(#{value_expr})"
        end

        # True when the encoder for `type` is the identity function — the
        # boundary wrapper can skip the encode call entirely.
        def identity_encoder?(type)
          scalar_qname(type) || list_scalar_qname(type) ? true : false
        end

        # Walks the module body for record types referenced by exposed
        # function boundaries; returns the distinct `Symbol::Struct`s
        # whose fields are all scalar / list-of-scalar.
        def collect_helpers(body, registry)
          body.expressions
            .filter { it.is_a?(AST::FunctionDeclaration) }
            .flat_map { fn_record_types(it, registry) }
            .uniq
        end

        # Emits the `decode_<name>` / `encode_<name>` methods for each
        # collected struct. Returns an array of Ruby def strings.
        def emit_helpers(structs, registry)
          structs.flat_map do
            [decode_helper(it, registry), encode_helper(it, registry)]
          end
        end

        private

        def scalar_qname(type)
          return nil unless args_of(type) == []

          qname_of(type).then { SCALAR_HELPER.key?(it) ? it : nil }
        end

        def list_scalar_qname(type)
          return nil unless qname_of(type) == 'List.List'
          args = args_of(type)
          return nil unless args&.size == 1

          scalar_qname(args[0])
        end

        # Returns the Symbol::Struct when `type` is a struct whose fields
        # are all scalar or list-of-scalar — i.e. a flat record we can
        # decode/encode inline. Returns nil otherwise (interfaces, unions,
        # structs with nested records, polymorphic structs).
        def record_struct(type, registry)
          return nil unless args_of(type) == []
          qname = qname_of(type) or return nil

          parts = qname.split('.')
          ref   = Symbol.type_ref(parts[0..-2].join('.'), parts[-1])
          sym   = registry.lookup(ref) or return nil
          return nil unless sym.is_a?(Symbol::Struct)
          return nil unless flat_record?(sym.record_type)

          sym
        end

        # Both `Type::Application` (from inferred boundary types) and
        # `Symbol::TypeApplication` (from struct field declarations) carry
        # the same constructor/args shape; normalize to a qname string.
        def qname_of(type)
          case type
          in Type::Application(constructor: Type::Constructor(name:))
            name

          in Symbol::TypeApplication(constructor: Symbol::TypeRef(module_name:, name: n))
            "#{module_name}.#{n}"

          else
            nil
          end
        end

        def args_of(type)
          case type
          in Type::Application(args:)         then args
          in Symbol::TypeApplication(args:)   then args
          else                                     nil
          end
        end

        def flat_record?(record_type)
          record_type.fields.values.all? do
            scalar_qname(it) || list_scalar_qname(it)
          end
        end

        def fn_record_types(fn_node, registry)
          symbol = fn_node.symbol
          return [] unless registry.get(symbol.module_name).exposed_value(symbol.name)

          fn_type = registry.get(symbol.module_name)
            .env
            .then { it.substitution.apply(it.bindings[symbol.qualified_name].type) }

          args, ret = Type.signature(fn_type)
          (args + [ret]).filter_map { record_struct(it, registry) }
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

        def decode_helper_name(struct)
          "decode_#{snake(struct.name)}"
        end

        def encode_helper_name(struct)
          "encode_#{snake(struct.name)}"
        end

        def decode_helper(struct, registry)
          ctor = "::#{to_qualified(struct.module_name)}::#{struct.name}"
          hash_call = "Jade::Interop::Boundary.hash(#{struct.name.inspect}, value)"

          struct.record_type.fields
            .map { |k, t| field_decode(k, t, registry) }
            .then { Pretty.call(ctor, it, open: '[', close: ']') }
            .then { Pretty.block("#{hash_call}.then do |h|", it) }
            .then { Pretty.block("def self.#{decode_helper_name(struct)}(value)", it) }
        end

        def encode_helper(struct, registry)
          struct.record_type.fields
            .map { |k, _| "#{k.inspect} => p.#{k}" }
            .then { "{ #{it.join(', ')} }" }
            .then { Pretty.block("def self.#{encode_helper_name(struct)}(p)", it) }
        end

        def field_decode(key, type, registry)
          access = "h[#{key.to_s.inspect}]"
          decode_expr(type, access, registry) ||
            fail("non-specializable field type for #{key}: #{type}")
        end

        def snake(name)
          name
            .gsub(/([A-Z]+)([A-Z][a-z])/, '\1_\2')
            .gsub(/([a-z\d])([A-Z])/, '\1_\2')
            .downcase
        end
      end
    end
  end
end
